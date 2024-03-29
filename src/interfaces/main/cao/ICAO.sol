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
import "./helpers/IHumanResources.sol";
import "./ICAOGovernor.sol";

/**
 * @title ICAO
 * @author Translucent
 *
 * @notice Interface for the centralized autonomous organization.
 */
interface ICAO is ICAOGovernor {
    /***************************************/
    /** Functions to set the CAO's helpers */
    /***************************************/
    function setCAOParameters(address parametersAddress) external;
    function setCAOHelpers(address humanResourcesAddress) external;

    /***************************************/
    /** Functions to get the CAO's helpers */
    /***************************************/
    function getHumanResources() external view returns (IHumanResources);

    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    function requireCAO(address caller) external view;
    function requireCAOTaskRunner(address caller) external view;

    /****************************************/
    /** Functions for employees interaction */
    /****************************************/
    function computeTokenRedeemAmount(
        address tokenAddress
    ) external view returns (uint256);
    function redeemRemuneration(address tokenAddress) external;
}
