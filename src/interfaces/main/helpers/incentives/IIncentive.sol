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
import "../../../../lib/Decimals.sol";

/**
 * @title IIncentive
 * @author Translucent
 *
 * @notice Interface for an instance of the main fund's incentives.
 */
interface IIncentive {
    /************************************/
    /** Functions to serve as modifiers */
    /************************************/
    function checkUserQualifies(address userAddress) external view returns (bool);

    /************************************/
    /** Functions for users to interact */
    /************************************/
    function getBalance(address userAddress) external view returns (uint256);
    function deposit(uint256 depositAmount) external;
    function withdraw(uint256 withdrawalAmount) external;

    /*****************************************/
    /** Functions for the incentives manager */
    /*****************************************/
    /** Computes the dilution weight for the incentive */
    function getDilutionWeight(
        Decimals.Number memory periodBeginningSupply,
        Decimals.Number memory returnsFactor
    ) external view returns (Decimals.Number memory);
    /** To be called before actual minting to update internal states */
    function recordDirectDeposit(address userAddress, uint256 amount) external;
    /** To be called before actual disbursement to update internal states */
    function recordDisbursement(uint256 amount) external;
}
