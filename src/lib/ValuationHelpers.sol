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

// Code
import "./Decimals.sol";

/**
 * @title ValuationHelpers
 * @author Translucent
 *
 * Valuation helper for abstracting computational logic in valuing tokens.
 */
library ValuationHelpers {
    /** Libraries */
    using Decimals for Decimals.Number;

    /** Constants */
    uint8 public constant VALUATION_DECIMALS = 18;

    /****************************************************/
    /** Helper functions to work with the number struct */
    /****************************************************/
    /**
     * Gets the account's balance of a token.
     *
     * @param accountAddress - The account whose balance to value.
     * @param tokenAddress - The token to value.
     * @return - The balance number struct.
     */
    function getBalance(
        address tokenAddress,
        address accountAddress
    ) internal view returns (Decimals.Number memory) {
        // Get the token balance
        IERC20Metadata token = IERC20Metadata(tokenAddress);

        return Decimals.Number({
            value: token.balanceOf(accountAddress),
            decimals: token.decimals()
        });
    }

    /**
     * Gets the price read from the oracle.
     *
     * @param oracleAddress - The oralce to read the price from.
     * @return - The price number struct.
     */
    function getOraclePrice(
        address oracleAddress
    ) internal view returns (Decimals.Number memory) {
         // Get the oracle price
        AggregatorV3Interface oracle = AggregatorV3Interface(oracleAddress);
        (, int256 answer, , ,) = oracle.latestRoundData();

        return Decimals.Number({
            value: uint256(answer),
            decimals: oracle.decimals()
        });
    }

    /**
     * Gets the value of the balance held and price read from the oracle.
     *
     * @param accountAddress - The account whose balance to value.
     * @param tokenAddress - The token to value.
     * @param oracleAddress - The oracle to read the price from.
     * @return - The value number struct.
     */
    function getBalanceValueFromOracle(
        address tokenAddress,
        address accountAddress,
        address oracleAddress
    ) internal view returns (Decimals.Number memory) {
        return getBalance(tokenAddress, accountAddress)
            .scaleDecimals(VALUATION_DECIMALS)
            .mul(getOraclePrice(oracleAddress));
    }

    /**
     * Gets the value from the input amount and price read from the oracle.
     */
    function getValueFromAmountAndOracle(
        address tokenAddress,
        uint256 amount,
        address oracleAddress
    ) internal view returns (Decimals.Number memory) {
        return Decimals.Number(amount, IERC20Metadata(tokenAddress).decimals())
            .scaleDecimals(VALUATION_DECIMALS)
            .mul(getOraclePrice(oracleAddress));
    }

    /**
     * Gets the amount that corresponds to the input target value
     * based on the input price.
     *
     * @param tokenAddress - The token to get the amount of.
     * @param price - The input price.
     * @param targetValue - The value to correspond to.
     * @return - The amount number struct.
     */
    function getAmountFromPriceAndTargetValue(
        address tokenAddress,
        Decimals.Number memory price,
        Decimals.Number memory targetValue
    ) internal view returns (Decimals.Number memory) {
        return targetValue
            .scaleDecimals(IERC20Metadata(tokenAddress).decimals())
            .div(price);
    }

    /**
     * Gets the amount that corresponds to the input target value
     * based on the price read from the oracle.
     *
     * @param tokenAddress - The token to get the amount of.
     * @param oracleAddress - The  oracle to read the price from.
     * @param targetValue - The value to correspond to.
     * @return - The amount number struct.
     */
    function getAmountFromOracleAndTargetValue(
        address tokenAddress,
        address oracleAddress,
        Decimals.Number memory targetValue
    ) internal view returns (Decimals.Number memory) {
        return getAmountFromPriceAndTargetValue(
            tokenAddress,
            getOraclePrice(oracleAddress),
            targetValue
        );
    }
}
