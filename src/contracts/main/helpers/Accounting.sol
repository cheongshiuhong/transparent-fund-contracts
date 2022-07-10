/*
    Copyright 2022 Translucent.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache-2.0
*/

pragma solidity ^0.8.12;

// External libraries
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Code
import "../../../lib/Decimals.sol";
import "../../../interfaces/main/IMainFund.sol";
import "../../../interfaces/main/helpers/IMainFundToken.sol";
import "../../../interfaces/main/helpers/IIncentivesManager.sol";
import "../../../interfaces/main/helpers/incentives/IIncentive.sol";
import "../../../interfaces/main/helpers/IAccounting.sol";
import "./MainFundHelper.sol";

/**
 * @title Accounting
 * @author Translucent
 *
 * @notice Contract for the main fund's accounting department.
 */
contract Accounting is MainFundHelper, IAccounting {
    /** Libraries */
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IMainFundToken;
    using Decimals for Decimals.Number;

    /** Events */
    event EvaluationPeriodReset();

    /** Constants */
    // Recommended Maximum management fee = 50% of profits (0.5 ether)
    uint256 public immutable MAX_MANAGEMENT_FEE; // 18 decimals
    // Recommended minimum evaluation period = 1 week
    // (604800 secs / 3 secs per block) = 201600 blocks;
    uint32 public immutable MIN_EVALUATION_PERIOD_BLOCKS;

    /** Fund parameters */
    uint256 private _managementFee; // 18 decimals
    uint32 private _evaluationPeriodBlocks;

    /** Accounting states */
    AccountingState private _state;

    /** Constructor */
    constructor(
        address fundAddress,
        uint256 initialAumValue,
        uint256 initialFundTokenSupply,
        uint256 initialManagementFee,
        uint32 initialEvaluationPeriodBlocks,
        uint256 maxManagementFee,
        uint32 minEvaluationPeriodBlocks
    ) MainFundHelper(fundAddress) {
        require(
            initialManagementFee <= maxManagementFee,
            "Accounting: management fee too high"
        );
        require(
            initialEvaluationPeriodBlocks >= minEvaluationPeriodBlocks,
            "Accounting: evaluation period too short"
        );
        _resetAccountingState(initialAumValue, initialFundTokenSupply);        
        _managementFee = initialManagementFee;
        _evaluationPeriodBlocks = initialEvaluationPeriodBlocks;
        MAX_MANAGEMENT_FEE = maxManagementFee;
        MIN_EVALUATION_PERIOD_BLOCKS = minEvaluationPeriodBlocks;
    }

    /********************************************/
    /** Functions to manage the fund parameters */
    /********************************************/
    /**
     * Gets the management fee set for the fund.
     *
     * @return - The management fee in 18 decimals.
     */
    function getManagementFee() external view override returns (uint256) {
        return _managementFee;
    }

    /**
     * Gets the evaluation period blocks for the fund.
     *
     * @return - The number of blocks per evaluation period.
     */
    function getEvaluationPeriodBlocks() external view override returns (uint32) {
        return _evaluationPeriodBlocks;
    }

    /**
     * Sets the management fee for the fund.
     *
     * @param newManagementFee - The new fee to be set.
     */
    function setMangementFee(uint256 newManagementFee) external override {
        // Only callable by the CAO through governance
        getFund().getCAO().requireCAOGovernance(_msgSender());

        // Require that fee is not too high
        require(
            newManagementFee <= MAX_MANAGEMENT_FEE,
            "Accounting: management fee too high"
        );

        // Set it
        _managementFee = newManagementFee;
    }

    /**
     * Sets the evaluation period blocks for the fund.
     *
     * @param newEvaluationPeriodBlocks - The new period to be set.
     */
    function setEvaluationPeriodBlocks(
        uint32 newEvaluationPeriodBlocks
    ) external override {
        // Only callable by the CAO through governance
        getFund().getCAO().requireCAOGovernance(_msgSender());

        // Require that period is not too short
        require(
            newEvaluationPeriodBlocks >= MIN_EVALUATION_PERIOD_BLOCKS,
            "Accounting: evalution period too short"
        );

        // Set it
        _evaluationPeriodBlocks = newEvaluationPeriodBlocks;
    }

    /********************************************/
    /** Functions to read the accounting states */
    /********************************************/
    /**
     * Gets the value of the assets under management.
     *
     * @return - The value of the assets under management
     */
    function getAumValue() public view override returns (Decimals.Number memory) {
        return Decimals.Number(_state.aumValue, 18);
    }

    /**
     * Gets the intrinsic value of the fund token.
     * 
     * @return - The fund token's intrinsic value (our quoted-price). 
     */
    function getFundTokenPrice() external view override returns (Decimals.Number memory) {
        return getAumValue().div(
            Decimals.Number(getFund().getFundToken().totalSupply(), 18)
        );
    }

    /**
     * Gets the accounting state.
     *
     * @return - The accounting state struct.
     */
    function getState() external view override returns (AccountingState memory) {
        return _state;
    }

    /***********************************************/
    /** Functions to manage the accounting process */
    /***********************************************/
    /**
     * Keep up-to-date with deposit activites that mints fund tokens.
     *
     * @dev Updates the states to preserve accuracy and the fund token price.
     *
     * @param amountMinted - The amount of fund tokens minted in the deposit.
     */
    function recordDeposits(
        uint256 depositValue,
        uint256 amountMinted
    ) external override {
        // Only callable by the front office
        require(
            _msgSender() == address(getFund().getFrontOffice()),
            "Accounting: caller is not the front office"
        );
        AccountingState memory state = _state;
        _state = AccountingState({
            aumValue: state.aumValue + depositValue,
            periodBeginningBlock: state.periodBeginningBlock,
            periodBeginningAum: state.periodBeginningAum + depositValue,
            periodBeginningSupply: state.periodBeginningSupply + amountMinted,
            theoreticalSupply: state.theoreticalSupply + amountMinted
        });
    }

    /**
     * Keep up-to-date with withdrawal activites that mints fund tokens.
     *
     * @dev Updates the states to preserve accuracy and the fund token price.
     *
     * @param amountBurned - The amount of fund tokens burned in the withdrawal.
     */
    function recordWithdrawals(
        uint256 withdrawalValue,
        uint256 amountBurned
    ) external override {
        // Only callable by the front office
        require(
            _msgSender() == address(getFund().getFrontOffice()),
            "Accounting: caller is not the front office"
        );
        AccountingState memory state = _state;
        _state = AccountingState({
            aumValue: state.aumValue - withdrawalValue,
            periodBeginningBlock: state.periodBeginningBlock,
            periodBeginningAum: state.periodBeginningAum - withdrawalValue,
            periodBeginningSupply: state.periodBeginningSupply - amountBurned,
            theoreticalSupply: state.theoreticalSupply - amountBurned
        });
    }

    /**
     * Records the aum snapshot of the fund.
     *
     * @dev - This is called off-chain as a recurring task.
     *
     * @param newAumValue - The new aum value to be recorded.
     */
    function recordAumValue(uint256 newAumValue) external override {
        // Get the reference interface to the fund's contracts
        IMainFund fund = getFund();
        IIncentivesManager incentivesManager = fund.getIncentivesManager();
        IMainFundToken fundToken = fund.getFundToken();

        // Pull the state into memory
        AccountingState memory state = _state;

        // Only callable by the CAO's task runner
        fund.getCAO().requireCAOTaskRunner(_msgSender());

        // Record the aum value
        _state.aumValue = newAumValue;

        // Load values used more than once into memory
        Decimals.Number memory periodBeginningSupply =
            Decimals.Number(state.periodBeginningSupply, 18);

        // Compute returns factor
        // (1 + r_T) = v_C / v_B
        Decimals.Number memory returnsFactor = Decimals.Number(newAumValue, 18)
            .div(Decimals.Number(state.periodBeginningAum, 18));

        // Get the incentives dilution weights
        (
            Decimals.Number memory incentivesDilutionWeight,
            address[] memory incentivesAddresses,
            Decimals.Number[] memory incentivesDilutionWeights
        ) = incentivesManager.getDilutionDetails(
            periodBeginningSupply, returnsFactor
        );

        // Include the management fee dilution weight
        Decimals.Number memory totalDilutionWeight =
            Decimals.Number(_managementFee, 18).add(incentivesDilutionWeight);

        // Compute theoretical supply
        uint256 theoreticalSupply = _computeTheoreticalSupply(
            periodBeginningSupply,
            returnsFactor,
            totalDilutionWeight
        );

        // Adjust the actual supply with the theoretical by minting/burning
        // NOTE: this is solely to reflect a more updated intrinsic value
        //       and discourage anticipatory behaviours of holders/speculators.
        _adjustActualSupply(fundToken, theoreticalSupply);

        // Update theoretical supply and exit if period not ended
        if (block.number - state.periodBeginningBlock < _evaluationPeriodBlocks) {
            _state.theoreticalSupply = theoreticalSupply;
            return;
        }

        // End of evaluation period - reset accounting state and disburse
        _resetAccountingState(newAumValue, fundToken.totalSupply());
        _disburseFundTokens(
            fundToken,
            incentivesAddresses,
            incentivesDilutionWeights,
            totalDilutionWeight
        );
        emit EvaluationPeriodReset();
        return;
    }

    /******************************/
    /** Internal helper functions */
    /******************************/
    /**
     * Computes the theoretical supply based on the running AUM (PnL).
     *
     * @dev We keep this function pure to serve as a formula
     *      and avoid re-reading from storage.
     *
     * @param beginningSupply - The supply at the start of the evaluation period.
     * @param returnsFactor - The returns factor in the evaluation period till now.
     * @param dilutionWeight - The amount of dilution.
     */
    function _computeTheoreticalSupply(
        Decimals.Number memory beginningSupply,
        Decimals.Number memory returnsFactor,
        Decimals.Number memory dilutionWeight
    ) internal pure returns (uint256) {
        // Compute the theoretical supply
        // s_T = s_B x (1 + r_T) / (1 + r_I)
        return beginningSupply.mul(
            // (1 + r_T) / (1 + r_I)
            returnsFactor.div(
                // (1 + r_I) = 1 + r_T (1 - w) can be written as
                // (1 + r_I) = (1 + r_T) (1 - w) + w to avoid negative values
                returnsFactor.mul(
                    Decimals.Number(1 ether, 18).sub(dilutionWeight)
                ).add(dilutionWeight)
            )
        ).value;
    }

    function _adjustActualSupply(
        IMainFundToken fundToken,
        uint256 targetSupply
    ) internal {
        // Mint/Burn tokens (MOVE to own INTERNAL FUNCTION)
        uint256 actualSupply = fundToken.totalSupply();
        if (targetSupply > actualSupply) {
            // Mint if more is needed
            fundToken.mint(address(this), targetSupply - actualSupply);
        } else {
            // Burn the difference with supply lower-bounded by beginning supply
            fundToken.burn(
                address(this),
                actualSupply - (
                    targetSupply > _state.periodBeginningSupply
                    ? targetSupply
                    : _state.periodBeginningSupply
                )
            );
        }
    }

    /**
     * Resets the accounting state to markt he start of a new evaluation period.
     *
     * @param newAumValue - The aum value to track for the period.
     @ @param newActualSupply - The actual supply to track for the period.
     */
    function _resetAccountingState(
        uint256 newAumValue,
        uint256 newActualSupply
    ) internal {
        _state = AccountingState({
            aumValue: newAumValue,
            periodBeginningBlock: block.number,
            periodBeginningAum: newAumValue,
            periodBeginningSupply: newActualSupply,
            theoreticalSupply: newActualSupply
        });
    }

    /**
     * Disburses the fund token balance in the accountant.
     *
     * @param fundToken - The reference interface of the fund token contract.
     * @param incentivesAddresses - The addresses of the incentives to disburse to.
     * @param incentivesDilutionWeights - The dilution weight of each incentive.
     * @param totalDilutionWeight - The denominator for computation.
     */
    function _disburseFundTokens(
        IMainFundToken fundToken,
        address[] memory incentivesAddresses,
        Decimals.Number[] memory incentivesDilutionWeights,
        Decimals.Number memory totalDilutionWeight
    ) internal {
        Decimals.Number memory balance = Decimals.Number(
            fundToken.balanceOf(address(this)), 18
        );

        // Disburse the proportion of fund tokens to each incentive contract
        for (uint256 i = 0; i < incentivesAddresses.length; i++) {
            uint256 amount = balance
                .mul(incentivesDilutionWeights[i])
                .div(totalDilutionWeight)
                .value;

            // Only disburse if there is something to disburse
            if (amount > 0) {
                // Record the disbursement
                IIncentive(incentivesAddresses[i]).recordDisbursement(amount);

                // Transfer to the incentive is actually disbursing
                fundToken.safeTransfer(incentivesAddresses[i], amount);
            }
        }
        // Disburse the rest to the CAO
        fundToken.safeTransfer(
            address(getFund().getCAO()), fundToken.balanceOf(address(this))
        );
    }
}
