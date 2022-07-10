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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Code
import "../../../lib/mappings/EnumerableAddressToAddressMap.sol";
import "../../../lib/Decimals.sol";
import "../../../lib/ValuationHelpers.sol";
import "../../../interfaces/main/cao/ICAO.sol";
import "../../../interfaces/main/cao/helpers/IHumanResources.sol";
import "../helpers/MainFundToken.sol";
import "./helpers/HumanResources.sol";
import "./CAOGovernor.sol";

/**
 * @title ICAO
 * @author Translucent
 *
 * @notice The contract for the Centralized Autonomous Organization.
 */
contract CAO is CAOGovernor, ICAO {
    /** Libraries */
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableAddressToAddressMap for EnumerableAddressToAddressMap.Map;
    using Decimals for Decimals.Number;

    /** Helpers */
    IHumanResources private _humanResources;

    /** Access states */
    address private _taskRunner;

    /** Reserves states */
    EnumerableAddressToAddressMap.Map private _reserveTokensAndOracles;
    EnumerableSet.AddressSet private _fundTokens;

    /** Remuneration events */
    event RemunerationRedeemed(address redeemer, address token, uint256 amount);

    /** Constructor */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory initialHolders,
        uint256[] memory initialAmounts,
        address initialTaskRunner
    ) CAOGovernor(name, symbol, initialHolders, initialAmounts) {
        _taskRunner = initialTaskRunner;
    }

    /*********************************/
    /** Functions to set the helpers */
    /*********************************/
    function setCAOHelpers(address humanResourcesAddress) external override {
        // If already set, run checks first
        if (address(_humanResources) != address(0)) {
            // Only callable by the CAO through governance if already set
            requireCAOGovernance(_msgSender());
            require(
                humanResourcesAddress != address(0),
                "CAO: cannot migrate humanResources to the 0x0 address"
            );
        }

        // Set the helpers
        _humanResources = IHumanResources(humanResourcesAddress);
    }

    /*******************************************/
    /** Functions to get details about the CAO */
    /*******************************************/
    function getHumanResources() external view override returns (IHumanResources) {
        return _humanResources;
    }

    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    /**
     * Function that can be called in a function to ensure that only the
     * CAO's delegated task runner is able to call that function.
     *
     * @param caller - The address to check.
     */
    function requireCAOTaskRunner(address caller) external view override {
        require(
            caller == _taskRunner,
            "CAO: can only be called by the CAO's task runner"
        );
    }

    /******************************************/
    /** Function for managing the task runner */
    /******************************************/
    /**
     * Gets the current task runner.
     *
     * @return - The address of the current task runner.
     */
    function getTaskRunner() external view returns (address) {
        return _taskRunner;
    }

    /**
     * Sets the task runner used for running tasks.
     *
     * @param newTaskRunnerAddress - The new task runner to be set.
     */
    function setTaskRunner(address newTaskRunnerAddress) external {
        // Only callable by the CAO through governance
        requireCAOGovernance(_msgSender());

        // Cannot set to the 0x0 address
        require(
            newTaskRunnerAddress != address(0),
            "CAO: cannot set task runner to the 0x0 address"
        );

        // Set the task runner
        _taskRunner = newTaskRunnerAddress;
    }

    /**
     * Called in emergencies by CAO token holders.
     */
    function unsetTaskRunner() external {
        // Only callable by a CAO token holder
        requireCAOTokenHolder(_msgSender());
        _taskRunner = address(0);
    }

    /**********************************************/
    /** Functions for managing the reserve tokens */
    /**********************************************/
    /**
     * Gets the reserve tokens.
     *
     * @return - The array of reserve tokens addresses.
     */
    function getReserveTokens() external view override returns (address[] memory) {
        return _reserveTokensAndOracles.keys();
    }

    /**
     * Gets the oracle for a reserve token.
     *
     * @return - The address of the reserve token's oracle.
     */
    function getReserveTokenOracle(
        address tokenAddress
    ) external view override returns (address) {
        return _reserveTokensAndOracles.get(tokenAddress);
    }

    /**
     * Sets the oracles for the input reserve tokens.
     *
     * @notice Only callable via governance proecss.
     * @notice overrides if already exists.
     *
     * @param tokensAddresses - The array of reserve tokens to add/update.
     * @param oraclesAddresses - The array of oracles to set.
     */
    function setReserveTokensOracles(
        address[] calldata tokensAddresses,
        address[] calldata oraclesAddresses
    ) external override {
        // Only callable by the CAO through governance
        requireCAOGovernance(_msgSender());

        // Require that array lengths are valid
        require(
            tokensAddresses.length == oraclesAddresses.length,
            "CAO: invalid array lengths"
        );

        for (uint256 i = 0; i < tokensAddresses.length; i++) {
            _reserveTokensAndOracles.set(tokensAddresses[i], oraclesAddresses[i]);
        }
    }

    /**
     * Removes reserve tokens.
     *
     * @notice Only callable via governance proecss.
     *
     * @param tokensAddresses - The array of reserve tokens to remove.
     */
    function removeReserveTokens(
        address[] calldata tokensAddresses
    ) external override {
        // Only callable by the CAO through governance
        requireCAOGovernance(_msgSender());

        for (uint256 i = 0; i < tokensAddresses.length; i++) {
            _reserveTokensAndOracles.remove(tokensAddresses[i]);
        }
    }

    /*******************************************/
    /** Functions for managing the fund tokens */
    /*******************************************/
    /**
     * Gets the fund tokens.
     *
     * @return - The array of fund tokens addresses.
     */
    function getFundTokens() external view returns (address[] memory) {
        return _fundTokens.values();
    }

    /**
     * Adds fund tokens.
     *
     * @param fundTokensAddresses - The array of fund tokens addreses to add.
     */
    function addFundTokens(address[] calldata fundTokensAddresses) external {
        // Only callable by the CAO through governance
        requireCAOGovernance(_msgSender());
        
        for (uint256 i = 0; i < fundTokensAddresses.length; i++) {
            _fundTokens.add(fundTokensAddresses[i]);
        }
    }

    /**
     * Removes fund tokens.
     *
     * @param fundTokensAddresses - The array of fund tokens addreses to remove.
     */
    function removeFundTokens(address[] calldata fundTokensAddresses) external {
        // Only callable by the CAO through governance
        requireCAOGovernance(_msgSender());
        
        for (uint256 i = 0; i < fundTokensAddresses.length; i++) {
            _fundTokens.remove(fundTokensAddresses[i]);
        }
    }

    /****************************************/
    /** Functions for employees interaction */
    /****************************************/
    /**
     * Computes the amount of a given token that can be redeemed.
     *
     * @param tokenAddress - The address of the token to redeem.
     * @return - The amount of the tokens that 
     */
    function computeTokenRedeemAmount(
        address tokenAddress
    ) public view override returns (uint256) {
        // Retrieve the accrued value
        Decimals.Number memory currentRemunerationValue =
            _humanResources.getEmployeeCurrentRemuneration(_msgSender());

        // Check if token is a reserve token
        if (_reserveTokensAndOracles.contains(tokenAddress)) {
            // Retrieve the oracle address
            address oracleAddress = _reserveTokensAndOracles.get(tokenAddress);

            // Return the computed amount
            return ValuationHelpers.getAmountFromOracleAndTargetValue(
                tokenAddress,
                oracleAddress,
                currentRemunerationValue
            ).value;
        }

        // Check if token is a fund token
        if (_fundTokens.contains(tokenAddress)) {
            MainFundToken fundToken = MainFundToken(tokenAddress);

            // Return the computed amount
            return ValuationHelpers.getAmountFromPriceAndTargetValue(
                tokenAddress,
                fundToken.getFund().getAccounting().getFundTokenPrice(),
                currentRemunerationValue
            ).value;
        }

        // Revert if not a redeemable token
        revert("CAO: token not redeemable");
    }

    /**
     * Redeems the remuneration in the input token.
     *
     * @param tokenAddress - The address of the token to redeem.
     */
    function redeemRemuneration(address tokenAddress) external override {
        // Compute the amount of the token to be redeemed
        uint256 tokenRedeemAmount = computeTokenRedeemAmount(tokenAddress);

        // Require that there is something to redeem
        require(tokenRedeemAmount > 0, "CAO: nothing to redeem");

        // Reset the remuneration
        _humanResources.clearEmployeeRemuneration(_msgSender());

        // Transfer the tokens (reverts if insufficient)
        IERC20(tokenAddress).safeTransfer(_msgSender(), tokenRedeemAmount);

        // Emit the event
        emit RemunerationRedeemed(_msgSender(), tokenAddress, tokenRedeemAmount);
    }
}
