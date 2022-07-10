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
import "../../../lib/FrontOfficeHelpers.sol";

/**
 * @title IFrontOffice
 * @author Translucent
 *
 * @notice Interface for the main fund's front office department.
 */
interface IFrontOffice {
    /******************************************/
    /** Functions to facilitate user requests */
    /******************************************/
    /** Structs */
    /**
     * Lookup struct to invert the mapping to facilitate searching of
     * a user's latest request by tracking the accessors.
     */
    struct RequestAccessor {
        bool isDeposit;
        address token;
        uint256 queueNumber;
    }

    /** Read */
    function getUserRequestCount(
        address userAddress
    ) external view returns (uint256);
    function getUserRequestByAccessor(
        RequestAccessor memory accessor
    ) external view returns (FrontOfficeHelpers.Request memory);
    function getUserRequestByIndex(
        address userAddress,
        uint256 index
    ) external view returns (
        RequestAccessor memory,
        FrontOfficeHelpers.Request memory
    );
    function getDepositsQueueLength(
        address tokenAddress
    ) external view returns (uint256);

    function getWithdrawalsQueueLength(
        address tokenAddress
    ) external view returns (uint256);

    /** Write */
    function requestDeposit(
        address tokenAddress,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 blockDeadline,
        address incentive
    ) external;
    function requestWithdrawal(
        address tokenAddress,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 blockDeadline
    ) external;
    function cancelLatestRequest() external;
    function redeemFromFailedRequests(uint256[] calldata indexes) external;

    /***************************************************************/
    /** Functions to facilitate the processing of requests (tasks) */
    /***************************************************************/
    function processDeposits(
        address tokenAddress,
        uint256 maxRequestsToProcess // Limits txn size and allows batching
    ) external;
    function processWithdrawals(
        address tokenAddress,
        uint256 maxRequestsToProcess // Limits txn size and allows batching
    ) external;
}
