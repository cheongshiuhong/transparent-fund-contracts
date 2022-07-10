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
import "./helpers/IOpsGovernor.sol";

/**
 * @title IBaseFund
 * @author Translucent
 *
 * @notice Interface for the base fund.
 */
interface IBaseFund {    
    /****************************************/
    /** Functions to set the fund's helpers */
    /****************************************/
    function setBaseFundHelpers(address opsGovernorAddress) external;

    /*********************************************/
    /** Structs to facilitate making transactions*/
    /*********************************************/
    enum CallType {
        TOKEN,
        PROTOCOL,
        UTIL
    }
    struct CallInput {
        CallType callType;
        address callAddress;
        bytes callData;
        uint256 value;
    }

    /***********************************/
    /** Functions to make transactions */
    /***********************************/
    function call(CallInput calldata callInput) external;
    function multiCall(CallInput[] calldata callInputs) external;
}
