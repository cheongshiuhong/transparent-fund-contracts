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

/**
 * @title IAccounting
 * @author Translucent
 *
 * @notice Interface for the main fund's accounting department.
 */
interface IAccounting {

    /********************************************/
    /** Functions to manage the fund parameters */
    /********************************************/
    /** Read */
    function getManagementFee() external view returns (uint256);
    function getEvaluationPeriodBlocks() external view returns (uint32);

    /** Write */
    function setMangementFee(uint256 newManagementFee) external;
    function setEvaluationPeriodBlocks(uint32 newEvaluationPeriodBlocks) external;

    /********************************************/
    /** Functions to read the accounting states */
    /********************************************/
    struct AccountingState {
        uint256 aumValue;
        uint256 periodBeginningBlock;
        uint256 periodBeginningAum;
        uint256 periodBeginningSupply;
        uint256 theoreticalSupply;
    }

    function getAumValue() external view returns (Decimals.Number memory);
    function getFundTokenPrice() external view returns (Decimals.Number memory);
    function getState() external view returns (AccountingState memory);

    /*******************************************************/
    /** Functions to manage the accounting process (tasks) */
    /*******************************************************/
    function recordDeposits(
        uint256 depositValue,
        uint256 amountMinted
    ) external; // frontOffice task
    function recordWithdrawals(
        uint256 withdrawalValue,
        uint256 amountBurned
    ) external; // frontOffice task
    function recordAumValue(uint256 newAumValue) external; // accounting task
}
