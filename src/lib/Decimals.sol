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
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Decimals
 * @author Translucent
 *
 * Library to supoprt a struct that represents decimal numbers.
 */
library Decimals {
    struct Number {
        uint256 value;
        uint8 decimals;
    }

    /**
     * Scale the current value up or down based on the difference
     * between the current decimals and target decimals.
     *
     * @param self - The current number struct.
     * @param targetDecimals - The decimals to scale the current value to.
     * @return - The scaled number struct.
     */
    function scaleDecimals(
        Number memory self,
        uint8 targetDecimals
    ) internal pure returns (Number memory) {
        Number memory output = Number({ value: self.value, decimals: targetDecimals });

        if (self.decimals > targetDecimals) {
            // Scale down
            output.value = self.value / 10**(self.decimals - targetDecimals);
        } else {
            // Scale up
            output .value = self.value * 10**(targetDecimals - self.decimals);
        }

        return output;
    }

    /**
     * Adds two numbers and preserves the first number's decimals.
     *
     * @param self - The current number struct.
     * @param other - The other number struct.
     * @return - The computed number struct.
     */
    function add(
        Number memory self,
        Number memory other
    ) internal pure returns (Number memory) {
        return Number({
            value: self.value + scaleDecimals(other, self.decimals).value,
            decimals: self.decimals
        });
    }

    /**
     * Subtracts two numbers and preserves the first number's decimals.
     *
     * @param self - The current number struct.
     * @param other - The other number struct.
     * @return - The computed number struct.
     */
    function sub(
        Number memory self,
        Number memory other
    ) internal pure returns (Number memory) {
        return Number({
            value: self.value - scaleDecimals(other, self.decimals).value,
            decimals: self.decimals
        });
    }

    /**
     * Multiplies two numbers and preserves the first number's decimals.
     *
     * @param self - The current number struct.
     * @param other - The other number struct.
     * @return - The computed number struct.
     */
    function mul(
        Number memory self,
        Number memory other
    ) internal pure returns (Number memory) {
        return Number({
            value: self.value * other.value / 10**other.decimals,
            decimals: self.decimals
        });
    }

    /**
     * Divides two numbers and preserves the first number's decimals.
     *
     * @param self - The current number struct.
     * @param other - The other number struct.
     * @return - The computed number struct.
     */
    function div(
        Number memory self,
        Number memory other
    ) internal pure returns (Number memory) {
        return Number({
            value: self.value * 10**other.decimals / other.value,
            decimals: self.decimals
        });
    }

    /**
     * Compares if first number is greater than or equal to the second.
     *
     * @param self - The current number struct.
     * @param self - The other number struct.
     * @return - The computed number struct.
     */
    function gte(
        Number memory self,
        Number memory other
    ) internal pure returns (bool) {
        // Compare at the higher decimal precision
        if (self.decimals >= other.decimals)
            return self.value >= scaleDecimals(other, self.decimals).value;
        else
            return scaleDecimals(self, other.decimals).value >= other.value;
    }

    /**
     * Compares if first number is greater than the second.
     *
     * @param self - The current number struct.
     * @param self - The other number struct.
     * @return - The computed number struct.
     */
    function gt(
        Number memory self,
        Number memory other
    ) internal pure returns (bool) {
        // Compare at the higher decimal precision
        if (self.decimals >= other.decimals)
            return self.value > scaleDecimals(other, self.decimals).value;
        else
            return scaleDecimals(self, other.decimals).value > other.value;
    }

    /**
     * Compares if first number is less than or equal to the second.
     *
     * @param self - The current number struct.
     * @param self - The other number struct.
     * @return - The computed number struct.
     */
    function lte(
        Number memory self,
        Number memory other
    ) internal pure returns (bool) {
        // Compare at the higher decimal precision
        if (self.decimals >= other.decimals)
            return self.value <= scaleDecimals(other, self.decimals).value;
        else
            return scaleDecimals(self, other.decimals).value <= other.value;
    }
}
