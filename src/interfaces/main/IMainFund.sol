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
import "./cao/ICAO.sol";
import "./helpers/IMainFundToken.sol";
import "./helpers/IAccounting.sol";
import "./helpers/IFrontOffice.sol";
import "./helpers/IIncentivesManager.sol";

/**
 * @title IMainFund
 * @author Translucent
 *
 * @notice Interface for the centralized autonomous organization's token.
 */
interface IMainFund {
    /****************************************/
    /** Functions to set the fund's helpers */
    /****************************************/
    function setMainFundHelpers(
        address caoAddress,
        address tokenAddress,
        address accountingAddress,
        address frontOfficeAddress,
        address incentivesManagerAddress
    ) external;

    /****************************************/
    /** Functions to get the fund's helpers */
    /****************************************/
    function getCAO() external view returns (ICAO);
    function getFundToken() external view returns (IMainFundToken);
    function getAccounting() external view returns (IAccounting);
    function getFrontOffice() external view returns (IFrontOffice);
    function getIncentivesManager() external view returns (IIncentivesManager);

    /****************************************/
    /** Functions to facilitate withdrawals */
    /****************************************/
    function approveFrontOfficeForWithdrawals(
        address[] calldata tokensAddresses,
        uint256[] calldata amounts
    ) external;
}
