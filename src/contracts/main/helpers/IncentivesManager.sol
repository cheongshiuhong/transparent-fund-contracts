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
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Code
import "../../../lib/Decimals.sol";
import "../../../interfaces/main/helpers/incentives/IIncentive.sol";
import "../../../interfaces/main/helpers/IIncentivesManager.sol";
import "./MainFundHelper.sol";

/**
 * @title IncentivesManager
 * @author Translucent
 *
 * @notice Contract for the main fund's incentives manager to
 *         aggregate view calls to the incentives contracts.
 *         *transacting calls should still be called directly.
 */
contract IncentivesManager is Context, MainFundHelper, IIncentivesManager {
    /** Libraries */
    using EnumerableSet for EnumerableSet.AddressSet;
    using Decimals for Decimals.Number;

    /** Parameters */
    EnumerableSet.AddressSet private _incentives;

    /** Constructor */
    constructor(address fundAddress) MainFundHelper(fundAddress) {}

    /************************************************/
    /** Functions to read and modify the parameters */
    /************************************************/
    /**
     * Gets the array of incentives addresses.
     *
     * @return - The array of addresses of the incentives.
     */
    function getIncentives() external view override returns (address[] memory) {
        return _incentives.values();
    }

    /**
     * Adds an incentive into the set to be valid.
     *
     * @param incentiveAddress - The address to be added.
     */
    function addIncentive(address incentiveAddress) external override {
        // Only callable by the CAO through governance
        getFund().getCAO().requireCAOGovernance(_msgSender());

        _incentives.add(incentiveAddress);
    }

    /**
     * Removes an incentive into the set to be invalid.
     *
     * @param incentiveAddress - The address to be removed.
     */
    function removeIncentive(address incentiveAddress) external override {
        // Only callable by the CAO through governance
        getFund().getCAO().requireCAOGovernance(_msgSender());

        _incentives.remove(incentiveAddress);
    }

    /*********************************************************/
    /** Functions to aggregate the incentives for accounting */
    /*********************************************************/
    /**
     * Gets the dilution details of the addresses and the weights.
     *
     * @param periodBeginningSupply - The supply to use as the denominator.
     * @return - The total dilution weight.
     * @return - The addresses of each incentive.
     * @return - The weights of each incentive.
     */
    function getDilutionDetails(
        Decimals.Number memory periodBeginningSupply,
        Decimals.Number memory returnsFactor
    ) external view override returns (
        Decimals.Number memory,
        address[] memory,
        Decimals.Number[] memory
    ) {
        // Pull the addresses into memory
        address[] memory incentives = _incentives.values();

        Decimals.Number memory totalDilutionWeight = Decimals.Number(0, 18);
        Decimals.Number[] memory weights = new Decimals.Number[](incentives.length);
        for (uint i = 0; i < incentives.length; i++) {
            weights[i] = IIncentive(incentives[i])
                .getDilutionWeight(periodBeginningSupply, returnsFactor);
            totalDilutionWeight = totalDilutionWeight.add(weights[i]);
        }

        return (totalDilutionWeight, incentives, weights);
    }

    /******************************************/
    /** Functions for use by the front office */
    /******************************************/
    /**
     * Checks the validity of an incentive for a user.
     *
     * @param incentiveAddress - The address of the incentive to check.
     * @param userAddress - The address of the user to check.
     * @return - The code indicating if it is valid.
     */
    function checkValidity(
        address incentiveAddress,
        address userAddress
    )  public view override returns (ValidityCode) {
        // 0x0 incentive address means not applicable
        if (incentiveAddress == address(0))
            return ValidityCode.NOT_APPLICABLE;

        // Exit if incentive does not exist
        if (!_incentives.contains(incentiveAddress))
            return ValidityCode.NOT_FOUND;

        // Exit if user does not qualify for the incentive
        if (!IIncentive(incentiveAddress).checkUserQualifies(userAddress)) {
            return ValidityCode.NOT_QUALIFIED;
        }

        return ValidityCode.VALID;
    }
}
