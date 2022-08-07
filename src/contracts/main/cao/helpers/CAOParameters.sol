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

// Code
import "../../../../lib/mappings/EnumerableAddressToAddressMap.sol";
import "../../../../interfaces/main/cao/helpers/ICAOParameters.sol";
import "./CAOHelper.sol";

/**
 * @title CAOParameters
 * @author Translucent
 *
 * @notice The contract for the Centralized Autonomous Organization.
 */
contract CAOParameters is CAOHelper, ICAOParameters {
    /** Libraries */
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableAddressToAddressMap for EnumerableAddressToAddressMap.Map;

    /** Access states */
    address private _taskRunner;

    /** Reserves states */
    EnumerableAddressToAddressMap.Map private _reserveTokensAndOracles;
    EnumerableSet.AddressSet private _fundTokens;

    /** Remuneration events */
    event RemunerationRedeemed(address redeemer, address token, uint256 amount);

    /** Constructor */
    constructor(
        address caoAddress,
        address initialTaskRunner
    ) CAOHelper(caoAddress) {
        _taskRunner = initialTaskRunner;
    }

    /******************************************/
    /** Function for managing the task runner */
    /******************************************/
    /**
     * Gets the current task runner.
     *
     * @return - The address of the current task runner.
     */
    function getTaskRunner() external view returns (address) {
        return _taskRunner;
    }

    /**
     * Sets the task runner used for running tasks.
     *
     * @param newTaskRunnerAddress - The new task runner to be set.
     */
    function setTaskRunner(address newTaskRunnerAddress) external {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());

        // Cannot set to the 0x0 address
        require(
            newTaskRunnerAddress != address(0),
            "CAO: cannot set task runner to the 0x0 address"
        );

        // Set the task runner
        _taskRunner = newTaskRunnerAddress;
    }

    /**
     * Called in emergencies by CAO token holders.
     */
    function unsetTaskRunner() external {
        // Only callable by a CAO token holder
        getCAO().requireCAOTokenHolder(_msgSender());
        _taskRunner = address(0);
    }

    /**********************************************/
    /** Functions for managing the reserve tokens */
    /**********************************************/
    /**
     * Checks if the input token is a reserve token.
     *
     * @param tokenAddress - The token address to check.
     * @return - Whether the inptu token is a reserve token.
     */
    function isReserveToken(
        address tokenAddress
    ) external view override returns (bool) {
        return _reserveTokensAndOracles.contains(tokenAddress);
    }

    /**
     * Gets the reserve tokens.
     *
     * @return - The array of reserve tokens addresses.
     */
    function getReserveTokens() external view override returns (address[] memory) {
        return _reserveTokensAndOracles.keys();
    }

    /**
     * Gets the oracle for a reserve token.
     *
     * @return - The address of the reserve token's oracle.
     */
    function getReserveTokenOracle(
        address tokenAddress
    ) external view override returns (address) {
        return _reserveTokensAndOracles.get(tokenAddress);
    }

    /**
     * Sets the oracles for the input reserve tokens.
     *
     * @notice Only callable via governance proecss.
     * @notice overrides if already exists.
     *
     * @param tokensAddresses - The array of reserve tokens to add/update.
     * @param oraclesAddresses - The array of oracles to set.
     */
    function setReserveTokensOracles(
        address[] calldata tokensAddresses,
        address[] calldata oraclesAddresses
    ) external override {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());

        // Require that array lengths are valid
        require(
            tokensAddresses.length == oraclesAddresses.length,
            "CAO: invalid array lengths"
        );

        for (uint256 i = 0; i < tokensAddresses.length; i++) {
            _reserveTokensAndOracles.set(tokensAddresses[i], oraclesAddresses[i]);
        }
    }

    /**
     * Removes reserve tokens.
     *
     * @notice Only callable via governance proecss.
     *
     * @param tokensAddresses - The array of reserve tokens to remove.
     */
    function removeReserveTokens(
        address[] calldata tokensAddresses
    ) external override {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());

        for (uint256 i = 0; i < tokensAddresses.length; i++) {
            _reserveTokensAndOracles.remove(tokensAddresses[i]);
        }
    }

    /*******************************************/
    /** Functions for managing the fund tokens */
    /*******************************************/
    /**
     * Checks if the input token is a fund token.
     *
     * @param tokenAddress - The token address to check.
     * @return - Whether the inptu token is a fund token.
     */
    function isFundToken(address tokenAddress) external override view returns(bool) {
        return _fundTokens.contains(tokenAddress);
    }

    /**
     * Gets the fund tokens.
     *
     * @return - The array of fund tokens addresses.
     */
    function getFundTokens() external view returns (address[] memory) {
        return _fundTokens.values();
    }

    /**
     * Adds fund tokens.
     *
     * @param fundTokensAddresses - The array of fund tokens addreses to add.
     */
    function addFundTokens(address[] calldata fundTokensAddresses) external {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());
        
        for (uint256 i = 0; i < fundTokensAddresses.length; i++) {
            _fundTokens.add(fundTokensAddresses[i]);
        }
    }

    /**
     * Removes fund tokens.
     *
     * @param fundTokensAddresses - The array of fund tokens addreses to remove.
     */
    function removeFundTokens(address[] calldata fundTokensAddresses) external {
        // Only callable by the CAO through governance
        getCAO().requireCAOGovernance(_msgSender());
        
        for (uint256 i = 0; i < fundTokensAddresses.length; i++) {
            _fundTokens.remove(fundTokensAddresses[i]);
        }
    }
}
