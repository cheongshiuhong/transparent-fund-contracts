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
 * @title FrontOfficeHelpers
 * @author Translucent
 *
 * FrontOffice helper for providing the request and queue structs
 * to replicate a queue of deposits and withdrawal requests. 
 */
library FrontOfficeHelpers {
    /*******************/
    /** Request struct */
    /*******************/
    // NOTE: status NULL = 0 as default uninitialized status (do not change)
    //       this is so we can differentitate uninitialized from pending statuses.
    enum RequestStatus {
        NULL,
        PENDING,
        CANCELLED,
        SUCCESSFUL,
        AMOUNT_TOO_LARGE,
        EXPIRED,
        INSUFFICIENT_OUTPUT,
        INCENTIVE_NOT_FOUND,
        INCENTIVE_NOT_QUALIFIED,
        UNHANDLED
    }
    struct Request {
        address user;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 blockDeadline;
        address incentive; // used only for deposits (ignored for withdrawals)
        RequestStatus status;
        uint256 blockUpdated;
        uint256 computedAmountOut;
        bool isReclaimed;
    }

    /**
     * Helper function to check if a request is in the pending status.
     *
     * @param request - The request struct.
     * @return - Whether the request is pending or not.
     */
    function isPending(Request memory request) internal pure returns (bool) {
        return request.status == RequestStatus.PENDING;
    }

    /**
     * Helper function to check if a request is in the pending status.
     *
     * @param request - The request struct.
     * @return - Whether the request is pending or not.
     */
    function _isPending(Request storage request) internal view returns (bool) {
        return request.status == RequestStatus.PENDING;
    } 

    /**
     * Helper function to check if a request is in a failed status.
     *
     * @param request - The request struct.
     * @return - Whether the request is pending or not.
     */
    function isFailed(Request storage request) internal view returns (bool) {
        RequestStatus status = request.status;
        return status == RequestStatus.EXPIRED
            || status == RequestStatus.INSUFFICIENT_OUTPUT
            || status == RequestStatus.INCENTIVE_NOT_FOUND
            || status == RequestStatus.INCENTIVE_NOT_QUALIFIED
            || status == RequestStatus.UNHANDLED;
    } 

    /**
     * Sets the status of a request to failed.
     *
     * @param request - The request struct.
     */
    function setCancelled(Request storage request) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to cancelled"
        );
        request.status = RequestStatus.CANCELLED;
        request.blockUpdated = block.number;
    }

    /**
     * Sets the status of a request to amount too large.
     *
     * @param request - The request struct.
     */
    function setAmountTooLarge(Request storage request) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to failed"
        );
        request.status = RequestStatus.AMOUNT_TOO_LARGE;
        request.blockUpdated = block.number;
    }

    /**
     * Sets the status of a request to expired.
     *
     * @param request - The request struct.
     */
    function setExpired(Request storage request) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to failed"
        );
        request.status = RequestStatus.EXPIRED;
        request.blockUpdated = block.number;
    }

    /**
     * Sets the status of a request to insufficient output.
     *
     * @param request - The request struct.
     */
    function setInsufficientOutput(
        Request storage request,
        uint256 computedAmountOut
    ) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to failed"
        );
        request.status = RequestStatus.INSUFFICIENT_OUTPUT;
        request.blockUpdated = block.number;
        request.computedAmountOut = computedAmountOut;
    }

    /**
     * Sets the status of a request to incentive not found.
     *
     * @param request - The request struct.
     */
    function setIncentiveNotFound(
        Request storage request,
        uint256 computedAmountOut
    ) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to failed"
        );
        request.status = RequestStatus.INCENTIVE_NOT_FOUND;
        request.blockUpdated = block.number;
        request.computedAmountOut = computedAmountOut;
    }

    /**
     * Sets the status of a request to incentive not qualified.
     *
     * @param request - The request struct.
     */
    function setIncentiveNotQualified(
        Request storage request,
        uint256 computedAmountOut
    ) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to failed"
        );
        request.status = RequestStatus.INCENTIVE_NOT_QUALIFIED;
        request.blockUpdated = block.number;
        request.computedAmountOut = computedAmountOut;
    }

    /**
     * Sets the status of a request to unhandled.
     *
     * @param request - The request struct.
     */
    function setUnhandled(Request storage request) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to unhandled"
        );
        request.status = RequestStatus.UNHANDLED;
        request.blockUpdated = block.number;
    }

    /**
     * Sets the status of a request to success.
     *
     * @param request - The request struct.
     */
    function setSuccessful(
        Request storage request,
        uint256 computedAmountOut
    ) internal {
        require(
            _isPending(request),
            "FrontOfficeLib: cannot set a non-pending request to successful"
        );
        request.status = RequestStatus.SUCCESSFUL;
        request.blockUpdated = block.number;
        request.computedAmountOut = computedAmountOut;
    }

    /*****************/
    /** Queue struct */
    /*****************/
    struct Queue {
        mapping(uint256 => Request) requests;
        uint256 readIdx;
        uint256 writeIdx;
    }

    /**
     * Gets the length of the queue.
     *
     * @param queue - The queue struct.
     * @return - The `length` based on the difference between the indexes.
     */
    function length(Queue storage queue) internal view returns (uint256) {
        return queue.writeIdx - queue.readIdx;
    }

    /**
     * Pushes a request into the queue.
     *
     * @param queue - The queue struct.
     * @param userAddress - The address of the user.
     * @param amountIn - The input amount. 
     * @param minAmountOut - The min output amount for the request to succeed.
     * @param blockDeadline - The latest block that the request can be executed
     * @return - The queue number (index) of the request.
     */
    function push(
        Queue storage queue,
        address userAddress,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 blockDeadline,
        address incentive
    ) internal returns (uint256) {
        // Pull the current writeIdx into memory
        uint256 currentWriteIdx = queue.writeIdx;

        // Write into the queue at the current writeIdx
        queue.requests[currentWriteIdx] = Request({
            user: userAddress,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            blockDeadline: blockDeadline,
            incentive: incentive,
            status: RequestStatus.PENDING,
            blockUpdated: 0,
            computedAmountOut: 0,
            isReclaimed: false
        });

        // Increment the writeIdx
        queue.writeIdx++;

        // Return the current writeIdx
        return currentWriteIdx;
    }

    /**
     * Reads the first request in the queue.
     *
     * @param queue - The queue struct.
     * @return - The reference to the request.
     */
    function front(
        Queue storage queue
    ) internal view returns (Request storage) {
        return queue.requests[queue.readIdx];
    }

    /**
     * Pops a request from the queue.
     *
     * @dev This replicates the interface of a queue's pop op
     *      although we never actually `pop` the request from the map,
     *      merely incrementing the readIdx.
     *
     * @dev We also do not perform checks on the index since it is guaranteed
     *      that we will not pop beyond the write index internally.
     *
     * @param queue - The queue struct.
     */
    function pop(Queue storage queue) internal {
        // Increment the readIdx 
        queue.readIdx++;
    }
}
