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

// Disable linting for low-level calls
// solhint-disable avoid-low-level-calls
// solhint-disable no-inline-assembly

/**
 * @title LowLevelHelpers
 * @author Translucent
 *
 * Low-level helper for performing low-level calls.
 */
library LowLevelHelpers {
    /**
     * Handler to revert with returnData's revert string if it exists
     *
     * @param returnData - The return data from the call.
     */
    function handleRevert(bytes memory returnData)
        internal
        pure
    {
        // Log the return data message if any
        if (returnData.length > 0) {
            assembly {
                let returnDataSize := mload(returnData)
                revert(add(32, returnData), returnDataSize)
            }
        } else {
            revert("Function call reverted");
        }
    }

    /**
     * Slice the bytes to return a sub-array of bytes
     *
     * @param bytesData - The input bytes data to slice.
     * @param start - The index to start slicing.
     * @param length - The length of the sub-array to slice.
     * @return bytes memory - The sliced sub-array of bytes.
     */
    function sliceBytes(bytes memory bytesData, uint256 start, uint256 length)
        internal
        pure
        returns (bytes memory)
    {
        require(
            bytesData.length >= (start + length),
            "sliceBytes: input bytes length must be >= start + length"
        );

        bytes memory tempBytes;

        assembly {
            switch iszero(length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(bytesData, lengthmod), mul(0x20, iszero(lengthmod))), start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    /**
     * Casts bytes into address by evaluating the first 20 bytes
     *
     * @param bytesData - The input bytes data to cast into address.
     * @return address - The casted address.
     */
    function bytesToAddress(bytes memory bytesData) internal pure returns (address) {
        require(
            bytesData.length >= 20,
            "bytesToAddress: input bytes length must be at least 20"
        );

        address addr;
        assembly {
            addr := mload(add(bytesData, 20))
        }
        return addr;
    }

    /**
     * Performs a low-level call without ETH
     *
     * @param callAddress - The address to call.
     * @param callData - The data to make the call with.
     */
    function performCall(
        address callAddress,
        bytes memory callData
    ) internal returns (bytes memory) {
        // Perform the call
        bool success;
        bytes memory returnData;

        // Call without eth value sent
        (success, returnData) = callAddress.call(callData);

        // Revert any potential low-level failures/reverts
        if (!success) handleRevert(returnData);

        return returnData;
    }

    /**
     * Performs a low-level call with ETH (although can be 0)
     *
     * @param callAddress - The address to call.
     * @param callData - The data to make the call with.
     * @param value - The amount of ETH to send as msg.value.
     */
    function performCall(
        address callAddress,
        bytes memory callData,
        uint256 value
    ) internal returns (bytes memory) {
        // Perform the call
        bool success;
        bytes memory returnData;

        // Call with eth value sent if input deems a need for it
        (success, returnData) = callAddress.call{value: value}(callData);

        // Revert any potential low-level failures/reverts
        if (!success) handleRevert(returnData);

        return returnData;
    }

    /**
     * Performs a delegate call with the bytes data
     *
     * @param callAddress - The address to call.
     * @param callData - The data to make the call with.
     */
    function performDelegateCall(
        address callAddress,
        bytes memory callData
    ) internal returns (bytes memory) {
        // Perform the call
        bool success;
        bytes memory returnData;

        // No ETH to be sent for delegate calls
        // Any such requirement should be done on the impleemntation side
        (success, returnData) = callAddress.delegatecall(callData);

        // Revert any potential low-level failures/reverts
        if (!success) handleRevert(returnData);

        return returnData;
    }
}
