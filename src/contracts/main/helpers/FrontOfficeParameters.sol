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
import "@openzeppelin/contracts/access/Ownable.sol";

// Code
import "../../../lib/mappings/EnumerableAddressToAddressMap.sol";
import "../../../interfaces/main/helpers/IFrontOfficeParameters.sol";
import "./MainFundHelper.sol";

/**
 * @title FrontOfficeParameters
 * @author Translucent
 *
 * @notice Contract for the main fund's front office department's parameters.
 * @notice Kept in a separate contract to reduce front office contract's size.
 */
contract FrontOfficeParameters is MainFundHelper, IFrontOfficeParameters {
    /** Libraries */
    using EnumerableAddressToAddressMap for EnumerableAddressToAddressMap.Map;

    /** Parameters */
    EnumerableAddressToAddressMap.Map private _allowedTokensAndOracles;
    uint256 private _maxSingleWithdrawalFundTokenAmount;

    /** Constructor  */
    constructor(
        address fundAddress,
        address[] memory initialAllowedTokens,
        address[] memory initialOraclesAddresses,
        uint256 initialMaxSingleWithdrawalFundTokenAmount
    ) MainFundHelper(fundAddress) {
        // Require valid input array lengths
        require(
            initialAllowedTokens.length == initialOraclesAddresses.length,
            "FrontOfficeParameters: invalid array lengths"
        );

        for (uint256 i = 0; i < initialAllowedTokens.length; i++)
            _allowedTokensAndOracles
                .set(initialAllowedTokens[i], initialOraclesAddresses[i]);
        
        _maxSingleWithdrawalFundTokenAmount =
            initialMaxSingleWithdrawalFundTokenAmount;
    }

    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    function requireAllowedToken(address tokenAddress) external view {
        require(
            _allowedTokensAndOracles.contains(tokenAddress),
            "FrontOfficeParameters: token is not allowed"
        );
    }

    /*******************************************************/
    /** Functions to facilitate the managing of parameters */
    /*******************************************************/
    /**
     * Gets the addresses of the allowed tokens.
     *
     * @return - The array of the allowed tokens' addresses.
     */
    function getAllowedTokens() external view override returns (address[] memory) {
        return _allowedTokensAndOracles.keys();
    }

    /**
     * Gets the address of the allowed token's oracle.
     *
     * @param tokenAddress - The address of the token to lookup.
     * @return - The address of the allowed token's oracle.
     */
    function getAllowedTokenOracle(
        address tokenAddress
    ) external view override returns (address) {
        return _allowedTokensAndOracles.get(tokenAddress);
    }

    /**
     * Gets the max single withdrawal fund token amount parameter value.
     *
     * @return - The parameter value.
     */
    function getMaxSingleWithdrawalFundTokenAmount() external view returns (uint256) {
        return _maxSingleWithdrawalFundTokenAmount;
    }

    /**
     * Sets the tokens and the oracles to be allowed.
     *
     * @param tokensAddresses - The addresses of the tokens to be allowed.
     * @param oraclesAddresses - The addresses of the oracles to be allowed.
     */
    function setAllowedTokens(
        address[] calldata tokensAddresses,
        address[] calldata oraclesAddresses
    ) external override {
        // Only callable by the CAO through governance
        getFund().getCAO().requireCAOGovernance(_msgSender());

        // Require valid input array lengths
        require(
            tokensAddresses.length == oraclesAddresses.length,
            "FrontOfficeParameters: invalid array lengths"
        );

        // Set into the map
        for (uint i = 0; i < tokensAddresses.length; i++)
            _allowedTokensAndOracles
                .set(tokensAddresses[i], oraclesAddresses[i]);
    }

    /**
     * Removes the tokens from being allowed.
     *
     * @param tokensAddresses - The addresses of the tokens to be removed.
     */
    function removeAllowedTokens(
        address[] calldata tokensAddresses
    ) external override {
        // Only callable by the CAO through governance
        getFund().getCAO().requireCAOGovernance(_msgSender());

        // Remove from the map
        for (uint i = 0; i < tokensAddresses.length; i++) {
            _allowedTokensAndOracles.remove(tokensAddresses[i]);
        }
    }

    /**
     * Sets the max single withdrawal fund token amount.
     *
     * @param amount - The new amount to set.
     */
    function setMaxSingleWithdrawalFundTokenAmount(uint256 amount) external override {
        // Only callable by the CAO through governance
        getFund().getCAO().requireCAOGovernance(_msgSender());

        // Set the new parameter value
        _maxSingleWithdrawalFundTokenAmount = amount;
    }
}
