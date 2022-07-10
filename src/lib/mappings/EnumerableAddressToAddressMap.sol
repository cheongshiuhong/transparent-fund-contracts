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
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title EnumerableAddressToAddressMap
 * @author Translucent
 *
 * @notice Helper library for the modules registry adapted from
 *         openzeppelin's EnumerableMap for address => address mapping.
 */
library EnumerableAddressToAddressMap {
    /** Libraries */
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Map {
        EnumerableSet.AddressSet _keys;
        mapping(address => address) _values;
    }

    function keys(Map storage map) internal view returns (address[] memory) {
        return map._keys.values();
    }

    function length(Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }
 
    function contains(Map storage map, address key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    function get(Map storage map, address key) internal view returns (address) {
        return map._values[key];
    }

    function getKeyAtIndex(
        Map storage map,
        uint256 index
    ) internal view returns (address) {
        return map._keys.at(index);
    }

    function set(
        Map storage map,
        address key,
        address value
    ) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    function remove(Map storage map, address key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }
}
