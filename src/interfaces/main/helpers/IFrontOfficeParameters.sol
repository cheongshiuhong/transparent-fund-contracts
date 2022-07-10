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
 * @title IFrontOfficeParameters
 * @author Translucent
 *
 * @notice Interface for the main fund's front office department's parameters.
 */
interface IFrontOfficeParameters {
    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    function requireAllowedToken(address tokenAddress) external view;

    /*******************************************************/
    /** Functions to facilitate the managing of parameters */
    /*******************************************************/
    /** Read */
    function getAllowedTokens() external view returns (address[] memory);
    function getAllowedTokenOracle(address tokenAddress) external view returns (address);
    function getMaxSingleWithdrawalFundTokenAmount() external view returns (uint256);

    /** Write */
    function setAllowedTokens(
        address[] calldata tokensAddresses,
        address[] calldata oraclesAddresses
    ) external;
    function removeAllowedTokens(address[] calldata tokensAddresses) external;
    function setMaxSingleWithdrawalFundTokenAmount(uint256 amount) external;
}
