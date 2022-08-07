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

/**
 * @title ICAOParameters
 * @author Translucent
 *
 * @notice Interface for the cao's parameters.
 */
interface ICAOParameters {
/******************************************/
    /** Function for managing the task runner */
    /******************************************/
    function getTaskRunner() external view returns (address);
    function setTaskRunner(address newTaskRunnerAddress) external;
    function unsetTaskRunner() external;

    /**********************************************/
    /** Functions for managing the reserve tokens */
    /**********************************************/
    function isReserveToken(address tokenAddress) external view returns (bool);
    function getReserveTokens() external view returns (address[] memory);
    function getReserveTokenOracle(address tokenAddress) external view returns (address);
    function setReserveTokensOracles(
        address[] calldata tokensAddresses,
        address[] calldata oraclesAddresses
    ) external;
    function removeReserveTokens(address[] calldata tokensAddresses) external;

    /*******************************************/
    /** Functions for managing the fund tokens */
    /*******************************************/
    function isFundToken(address tokenAddress) external view returns(bool);
    function getFundTokens() external view returns (address[] memory);
    function addFundTokens(address[] calldata fundTokensAddresses) external;
    function removeFundTokens(address[] calldata fundTokensAddresses) external;
}
