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
 * @title IOpsGovernor
 * @author Translucent
 *
 * @notice Interface for managing and governing operations.
 * @notice Governance is solely based on managers that voted.
 *         Non-voting is abstained by default.
 */
interface IOpsGovernor {
    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    function requireManagers(address caller) external view;
    function requireOperators(address caller) external view;
    function requireTokenRegistered(address tokenAddress) external view;
    function requireProtocolRegistered(address protocolAddress) external view;
    function requireUtilRegistered(address utilAddress) external view;

    /*********************************/
    /** Functions to read the states */
    /*********************************/
    function getManagers() external view returns (address[] memory);
    function getOperators() external view returns (address[] memory);
    function getNumRegisteredTokens() external view returns (uint256);
    function getNumRegisteredProtocols() external view returns (uint256);
    function getNumRegisteredUtils() external view returns (uint256);
    function getRegisteredTokens(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory);
    function getRegisteredProtocols(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory);
    function getRegisteredUtils(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory);

    /***********************************/
    /** Functions to modify the states */
    /***********************************/
    function addManager(address managerAddress) external;
    function removeManager(address managerAddress) external;
    function addOperator(address operatorAddress) external;
    function removeOperator(address operatorAddress) external;
    function registerTokens(address[] memory tokensAddresses) external;
    function unregisterTokens(address[] memory tokensAddresses) external;
    function registerProtocols(address[] memory protocolsAddresses) external;
    function unregisterProtocols(address[] memory protocolsAddresses) external;
    function registerUtils(address[] memory utilsAddresses) external;
    function unregisterUtils(address[] memory utilsAddresses) external;

    /*******************************************************/
    /** Function to migrate to a new ops governor contract */
    /*******************************************************/
    function migrate(address newOpsGovernorAddress) external;

    /************************************************/
    /** Structs to facilitate governance and voting */
    /************************************************/
    enum Direction { FOR, AGAINST }
    enum Status { PENDING, REJECTED, APPROVED_AND_EXECUTED, APPROVED_BUT_FAILED }

    struct Proposal {
        address proposer;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        bytes callData;
        uint256 votesFor;
        uint256 votesAgainst;
        Status status;
        uint256 blockExecuted;
    }
    /**************************************************/
    /** Functions to facilitate governance and voting */
    /**************************************************/
    function createProposal(
        string memory description,
        uint256 duration,
        bytes calldata callData
    ) external returns (uint256);
    function vote(uint256 proposalId, Direction direction) external;
    function executeProposal(uint256 proposalId) external returns (Status);

    /********************************************/
    /** Functions to read the governance states */
    /********************************************/
    function getNumProposals() external view returns (uint256);
    function getActiveProposalsIds() external view returns (uint256[] memory);
    function getProposal(uint256 proposalId) external view returns (Proposal memory);
    function getIsProposalExecutable(uint256 proposalId) external view returns (bool);
}
