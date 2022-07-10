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

// External libraries
import "@openzeppelin/contracts/utils/Context.sol";

// Code
import "../../lib/LowLevelHelpers.sol";
import "../../interfaces/base/helpers/IOpsGovernor.sol";
import "../../interfaces/base/IBaseFund.sol";

/**
 * @title BaseFund
 * @author Translucent
 *
 * @notice The basic fund contract that allows transacting with protocols.
 */
contract BaseFund is Context, IBaseFund {
    /** Helpers */
    IOpsGovernor private _opsGovernor;

    /** Events */
    event TransactCall(address indexed callAddress, bytes4 indexed selector);

    /** Receive function to allow receiving eth */
    receive() external payable {}

    /****************************************/
    /** Functions to set the fund's helpers */
    /****************************************/
    /**
     * Sets the helpers for the base fund.
     *
     * @param opsGovernorAddress - The address of the ops governor to set.
     */
    function setBaseFundHelpers(address opsGovernorAddress) external override {
        // If already set, run checks first
        if (address(_opsGovernor) != address(0)) {
            require(
                _msgSender() == address(_opsGovernor),
                "BaseFund: can only be migrated from the current ops governor"
            );
            require(
                opsGovernorAddress != address(0),
                "BaseFund: cannot migrate opsGovernor to the 0x0 address"
            );
        }

        // Set the helpers
        _opsGovernor = IOpsGovernor(opsGovernorAddress);
    }

    /******************************************************/
    /********* Functions to facilitate transactions *******/
    /******************************************************/
    /**
     * Performs a single call
     *
     * @notice Only operators can call this.
     * @param callInput - The inputs to make the call with.
     */
    function call(CallInput calldata callInput) external {
        _opsGovernor.requireOperators(_msgSender());
        _call(callInput);
    }

    /**
     * Performs multiple calls atomically
     *
     * @notice Only operators can call this.
     * @param callInputs - The array of inptus to make the calls with.
     */
    function multiCall(CallInput[] calldata callInputs) external {
        _opsGovernor.requireOperators(_msgSender());

        for (uint256 i = 0; i < callInputs.length; i++) {
            _call(callInputs[i]);
        }
    }

    /**
     * Performs checks based on call type and perform the call
     *
     * @param callInput - The inputs to call with.
     */
    function _call(CallInput memory callInput) internal {
        bytes4 selector = bytes4(
            LowLevelHelpers.sliceBytes(callInput.callData, 0, 4)
        );

        // Transact with a token (e.g. approve/increaseAllowance)
        if (callInput.callType == CallType.TOKEN) {
            // Require that the address is a registered token
            _opsGovernor.requireTokenRegistered(callInput.callAddress);
            
            // Run checks on the call data before executing
            _checkSelector(selector, callInput.callData);
            LowLevelHelpers.performCall(
                callInput.callAddress,
                callInput.callData,
                callInput.value
            );
        }

        // Transact directly with protocol
        else if (callInput.callType == CallType.PROTOCOL) {
            // Require that the address is a registered protocol
            _opsGovernor.requireProtocolRegistered(callInput.callAddress);

            // Run checks on the selector before executing
            _checkSelector(selector, callInput.callData);
            LowLevelHelpers.performCall(
                callInput.callAddress,
                callInput.callData,
                callInput.value
            );
        }

        // Transact via utils
        else if (callInput.callType == CallType.UTIL) {
            // Require that the address is a registered util
            _opsGovernor.requireUtilRegistered(callInput.callAddress);

            // Execute the delegate call
            LowLevelHelpers.performDelegateCall(
                callInput.callAddress,
                callInput.callData
            );
        }

        // Emit the event
        emit TransactCall(callInput.callAddress, selector);
    }

    /**
     * Checks the selector
     *
     * @param selector - The selector to check.
     * @param callData - The encoded call data to check.
     */
    function _checkSelector(bytes4 selector, bytes memory callData) internal view {
        require(
            // bytes4(keccak("transfer(address,uint256)")) --> 0xa9059cbb
            selector != bytes4(0xa9059cbb),
            "BaseFund: cannot call transfer function"
        );
        require(
            // bytes4(keccak("transferFrom(address,address,uint256)")) --> 0x23b872dd
            selector != bytes4(0x23b872dd),
            "BaseFund: cannot call transferFrom function"
        );
        require(
            // bytes4(keccak("mintBehalf(address,uint256)")) --> 0x23323e03
            selector != bytes4(0x23323e03),
            "BaseFund: cannot call mintBehalf function"
        );

        // Check the address in increaseAllowance and approve calls
        // that they are called only for protocols
        if (
            // bytes4(keccak("increaseAllowance(address,uint256)")) --> 0x39509351
            selector == bytes4(0x39509351)
            // bytes4(keccak("approve(address,uint256") --> 0x095ea7b3
            || selector == bytes4(0x095ea7b3)
        ) {
            address inputAddress = LowLevelHelpers.bytesToAddress(
                LowLevelHelpers.sliceBytes(callData, 16, 20)
            );
            _opsGovernor.requireProtocolRegistered(inputAddress);
        }
    }
}
