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
 * @title ICAOGovernor
 * @author Translucent
 *
 * @notice Interface for the centralized autonomous organization's governance.
 */
interface ICAOGovernor {
    /*******************************************************/
    /** Functions to get details and references of the CAO */
    /*******************************************************/
    function getName() external view returns (string memory);
    function getCAOTokenAddress() external view returns (address);

    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    function requireCAOGovernance(address caller) external view;
    function requireCAOTokenHolder(address caller) external view;

    /**************************************************/
    /** Functions to manage CAO governance parameters */
    /**************************************************/
    function setAdvanceExecutionThreshold(uint256 newThreshold) external;

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
        address[] callAddresses;
        bytes[] callDatas;
        uint256[] callValues;
        uint256 votesFor;
        uint256 votesAgainst;
        Status status;
        bytes[] returnDatas;
    }

    /**************************************************/
    /** Functions to facilitate governance and voting */
    /**************************************************/
    function createProposal(
        string memory description,
        uint256 blockDelay,
        uint256 blocksDuration,
        address[] calldata callAddresses,
        bytes[] calldata callDatas,
        uint256[] calldata callValues
    ) external returns (uint256);
    function vote(uint256 proposalId, Direction direction, string memory reason) external;
    function executeProposal(uint256 proposalId) external returns (Status);

    /********************************************/
    /** Functions to read the governance states */
    /********************************************/
    function getNumProposals() external view returns(uint256);
    function getActiveProposalsIds() external view returns (uint256[] memory);
    function getProposal(uint256 proposalId) external view returns (Proposal memory);
}
