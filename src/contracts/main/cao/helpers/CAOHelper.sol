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

import "@openzeppelin/contracts/utils/Context.sol";
import "../../../../interfaces/main/cao/ICAO.sol";

/**
 * @title CAOHelper
 * @author Translucent
 *
 * @notice Base contract for CAO helpers to inherit from,
 *         providing reference to the CAO contract.
 */
abstract contract CAOHelper is Context {
    address private _caoAddress;

    /**
     * Sets the cao
     */
    constructor(address caoAddress) {
        _caoAddress = caoAddress;
    }

    /**
     * @dev Returns the address of the CAO.
     */
    function getCAOAddress() public view returns (address) {
        return _caoAddress;
    }

    /**
     * @dev Returns the address of the CAO.
     */
    function getCAO() public view returns (ICAO) {
        return ICAO(_caoAddress);
    }
}
