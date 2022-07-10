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

// Code
import "../../../lib/Decimals.sol";
import "./incentives/IIncentive.sol";

/**
 * @title IIncentivesManager
 * @author Translucent
 *
 * @notice Interface for the main fund's incentives manager.
 */
interface IIncentivesManager {
    /************************************************/
    /** Functions to read and modify the parameters */
    /************************************************/
    function getIncentives() external view returns (address[] memory);
    function addIncentive(address incentiveAddress) external;
    function removeIncentive(address incentiveAddress) external;

    /*********************************************************/
    /** Functions to aggregate the incentives for accounting */
    /*********************************************************/
    function getDilutionDetails(
        Decimals.Number memory periodBeginningSupply,
        Decimals.Number memory returnsFactor
    ) external returns (
        Decimals.Number memory,
        address[] memory,
        Decimals.Number[] memory
    );

    /******************************************/
    /** Functions for use by the front office */
    /******************************************/
    enum ValidityCode { VALID, NOT_APPLICABLE, NOT_FOUND, NOT_QUALIFIED }
    function checkValidity(
        address incentiveAddress,
        address userAddress
    ) external returns (ValidityCode);
}
