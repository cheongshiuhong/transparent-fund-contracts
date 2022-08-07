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
import "../../../interfaces/main/cao/helpers/ICAOParameters.sol";
import "../helpers/MainFundToken.sol";
import "./helpers/HumanResources.sol";
import "./CAOGovernor.sol";

/**
 * @title CAO
 * @author Translucent
 *
 * @notice The contract for the Centralized Autonomous Organization.
 */
contract CAO is CAOGovernor, ICAO {
    /** Libraries */
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableAddressToAddressMap for EnumerableAddressToAddressMap.Map;
    using Decimals for Decimals.Number;

    /** Parameters */
    ICAOParameters private _parameters;

    /** Helpers */
    IHumanResources private _humanResources;

    /** Remuneration events */
    event RemunerationRedeemed(address indexed redeemer, address token, uint256 amount);

    /** Constructor */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory initialHolders,
        uint256[] memory initialAmounts
    ) CAOGovernor(name, symbol, initialHolders, initialAmounts) {}

    /************************************************/
    /** Functions to set the parameters and helpers */
    /************************************************/
    function setCAOParameters(
        address parametersAddress
    )  external override {
        // If already set, run checks first
        if (address(_parameters) != address(0)) {
            // Only callable by the CAO through governance if already set
            requireCAOGovernance(_msgSender());
            require(
                parametersAddress != address(0),
                "CAO: cannot migrate parameters to the 0x0 address"
            );
        }

        // Set the parameters
        _parameters = ICAOParameters(parametersAddress);
    }

    function setCAOHelpers(
        address humanResourcesAddress
    ) external override {
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
     * Function that can be called in a function to ensure that only the CAO
     * can call it either for governance or not.
     *
     * @param caller - The address to check.
     */
    function requireCAO(address caller) external view override {
        require(
            caller == address(this),
            "CAO: can only be called by the CAO"
        );
    }

    /**
     * Function that can be called in a function to ensure that only the
     * CAO's delegated task runner is able to call that function.
     *
     * @param caller - The address to check.
     */
    function requireCAOTaskRunner(address caller) external view override {
        require(
            caller == _parameters.getTaskRunner(),
            "CAO: can only be called by the CAO's task runner"
        );
    }

    /****************************************/
    /** Functions for employees interaction */
    /****************************************/
    /**
     * Computes the amount of a given token that can be redeemed.
     *
     * @param tokenAddress - The address of the token to redeem.
     * @return - The amount of the tokens that can be redeemed.
     */
    function computeTokenRedeemAmount(
        address tokenAddress
    ) public view override returns (uint256) {
        // Retrieve the accrued value
        Decimals.Number memory currentRemunerationValue =
            _humanResources.getEmployeeCurrentRemuneration(_msgSender());

        ICAOParameters parameters = _parameters;
        // Check if token is a reserve token
        if (parameters.isReserveToken(tokenAddress)) {
            // Retrieve the oracle address
            address oracleAddress = parameters.getReserveTokenOracle(tokenAddress);

            // Return the computed amount
            return ValuationHelpers.getAmountFromOracleAndTargetValue(
                tokenAddress,
                oracleAddress,
                currentRemunerationValue
            ).value;
        }

        // Check if token is a fund token
        if (parameters.isFundToken(tokenAddress)) {
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
