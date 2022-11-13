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

// External Libraries
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Code
import "./BaseFundHelper.sol";
import "../../../interfaces/base/helpers/IOpsGovernor.sol";

/**
 * @title OpsGovernor
 * @author Translucent
 *
 * @notice Contract for managing and simple governing operations.
 * @notice Voting is based on equal voting-rights of all managers,
 *         where a proposal can be executed if
 *         either the deadline is up or >50% of managers are in favour
 *         The success of the execution will then depend on if there
 *         are more votes FOR the proposal or more votes AGAINST it.
 */
contract OpsGovernor is BaseFundHelper, IOpsGovernor {
    /** Libraries */
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /** States */
    EnumerableSet.AddressSet private _managers;
    EnumerableSet.AddressSet private _operators;
    EnumerableSet.AddressSet private _tokens;
    EnumerableSet.AddressSet private _protocols;
    EnumerableSet.AddressSet private _utils;

    /** Governance states */
    Proposal[] private _proposals;
    EnumerableSet.UintSet private _activeProposalsIds;
    mapping(uint256 => EnumerableSet.AddressSet) private _voters;

    /** Governance events */
    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event Vote(uint256 indexed proposalId, address voter, Direction direction);
    event ProposalExecuted(uint256 indexed proposalId);

    /** Constructor */
    constructor(
        address fundAddress,
        address[] memory initialManagers,
        address[] memory initialOperators
    ) BaseFundHelper(fundAddress) {
        // Record the initial managers and operators
        for (uint i = 0; i < initialManagers.length; i++)
            _managers.add(initialManagers[i]);
        for (uint i = 0; i < initialOperators.length; i++)
            _operators.add(initialOperators[i]);
    }

    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    function requireManagers(address caller) public view override {
        require(
            _managers.contains(caller),
            "OpsGovernor: caller is not a manager"
        );
    }
    function requireOperators(address caller) external view override {
        require(
            _operators.contains(caller),
            "OpsGovernor: caller is not an operator"
        );
    }
    function requireTokenRegistered(address tokenAddress) external view override {
        require(
            _tokens.contains(tokenAddress),
            "OpsGovernor: token is not registered"
        );
    }
    function requireProtocolRegistered(address protocolAddress) external view override {
        require(
            _protocols.contains(protocolAddress),
            "OpsGovernor: protocol is not registered"
        );
    }
    function requireUtilRegistered(address utilAddress) external view override {
        require(
            _utils.contains(utilAddress),
            "OpsGovernor: util is not registered"
        );
    }

    /*********************************/
    /** Functions to read the states */
    /*********************************/
    function getManagers() external view override returns (address[] memory) {
        return _managers.values();
    }
    function getOperators() external view override returns (address[] memory) {
        return _operators.values();
    }
    function getNumRegisteredTokens() external view override returns (uint256) {
        return _tokens.length();
    }
    function getNumRegisteredProtocols() external view override returns (uint256) {
        return _protocols.length();
    }
    function getNumRegisteredUtils() external view override returns (uint256) {
        return _utils.length();
    }
    // TODO: Batch these getters since we might have alot of entries
    function getRegisteredTokens(
        uint256 offset,
        uint256 limit
    ) external view override returns (address[] memory) {
        address[] memory tokensAddresses = _tokens.values();
        return _batchAddresses(tokensAddresses, offset, limit);
    }
    function getRegisteredProtocols(
        uint256 offset,
        uint256 limit
    ) external view override returns (address[] memory) {
        address[] memory protocolsAddresses = _protocols.values();
        return _batchAddresses(protocolsAddresses, offset, limit);
    }
    function getRegisteredUtils(
        uint256 offset,
        uint256 limit
    ) external view override returns (address[] memory) {
        address[] memory utilsAddresses = _utils.values();
        return _batchAddresses(utilsAddresses, offset, limit);
    }
    function _batchAddresses(
        address[] memory addresses,
        uint256 offset,
        uint256 limit
    ) internal pure returns (address[] memory) {
        uint256 numOutput = _min(addresses.length - offset, limit);
        address[] memory output = new address[](numOutput);
        for (uint256 i = 0; i < numOutput; i++) {
            output[i] = addresses[offset + i];
        }
        return output;
    }
    function _min(uint256 val1, uint256 val2) internal pure returns (uint256) {
        return val1 < val2 ? val1 : val2;
    }

    /***********************************/
    /** Functions to modify the states */
    /***********************************/
    modifier onlyGovernance() {
        require(
            _msgSender() == address(this),
            "OpsGovernor: can only be called through governance process"
        );
        _;
    }
    function addManager(address managerAddress) external onlyGovernance override {
        _managers.add(managerAddress);
    }
    function removeManager(address managerAddress) external onlyGovernance override {
        require(_managers.length() > 1, "Ops Governor: Cannot remove the last manager");
        _managers.remove(managerAddress);
    }
    function addOperator(address operatorAddress) external onlyGovernance override {
        _operators.add(operatorAddress);
    }
    function removeOperator(address operatorAddress) external override {
        requireManagers(_msgSender());
        _operators.remove(operatorAddress);
    }
    function registerTokens(address[] calldata addresses) external onlyGovernance override {
        for (uint i = 0; i < addresses.length; i++)
            _tokens.add(addresses[i]);
    }
    function unregisterTokens(address[] calldata addresses) external override {
        requireManagers(_msgSender());
        for (uint i = 0; i < addresses.length; i++)
            _tokens.remove(addresses[i]);
    }
    function registerProtocols(address[] calldata addresses) external onlyGovernance override {
        for (uint i = 0; i < addresses.length; i++)
            _protocols.add(addresses[i]);
    }
    function unregisterProtocols(address[] calldata addresses) external override {
        requireManagers(_msgSender());
        for (uint i = 0; i < addresses.length; i++)
            _protocols.remove(addresses[i]);
    }
    function registerUtils(address[] calldata addresses) external onlyGovernance override {
        for (uint i = 0; i < addresses.length; i++)
            _utils.add(addresses[i]);
    }
    function unregisterUtils(address[] calldata addresses) external override {
        requireManagers(_msgSender());
        for (uint i = 0; i < addresses.length; i++)
            _utils.remove(addresses[i]);
    }

    /*******************************************************/
    /** Function to migrate to a new ops governor contract */
    /*******************************************************/
    function migrate(address newOpsGovernorAddress) external onlyGovernance {
        getFund().setBaseFundHelpers(newOpsGovernorAddress);
    }

    /**************************************************/
    /** Functions to facilitate governance and voting */
    /**************************************************/
    /**
     * Function for managers to create a proposal.
     *
     * @param description - Description about what the proposal is for/about.
     * @param duration - How long the voting should last.
     * @param callData - The calldata to be executed upon approval.
     * @return - The id of proposal for voting/execution. 
     */
    function createProposal(
        string memory description,
        uint256 duration,
        bytes calldata callData
    ) external override returns (uint256) {
        // Only managers can create proposals
        requireManagers(_msgSender());
        
        // Get the proposal ID as the index of the array
        uint256 proposalId = _proposals.length;

        // Track this as an active proposal
        _activeProposalsIds.add(proposalId);

        // Create the proposal struct
        _proposals.push(
            Proposal({
                proposer: _msgSender(),
                description: description,
                startBlock: block.number,
                endBlock: block.number + duration,
                callData: callData,
                votesFor: 1, // Proposer is by default in favour
                votesAgainst: 0,
                status: Status.PENDING,
                blockExecuted: 0
            })
        );

        // Record the proposer as having voted
        _voters[proposalId].add(_msgSender());

        // Emit the event of a proposal being created
        emit ProposalCreated(proposalId, _msgSender(), description);

        // Emit the event of the proposer voting FOR
        emit Vote(proposalId, _msgSender(), Direction.FOR);

        return proposalId;
    }

    /**
     * Function for managers to cast their votes on a proposal.
     *
     * @param proposalId - The id of the proposal to vote on.
     * @param direction - The vote direction of FOR or AGAINST.
     */
    function vote(uint256 proposalId, Direction direction) external override {
        // Only managers can vote
        requireManagers(_msgSender());

        // Require that voting is still active
        require(
            _proposals[proposalId].endBlock >= block.number,
            "OpsGovernor: voting for the proposal has ended"
        );

        // Require that the voter has not voted
        require(
            !_voters[proposalId].contains(_msgSender()),
            "OpsGovernor: caller has already voted"
        );

        // Record the vote
        if (direction == Direction.FOR)
            _proposals[proposalId].votesFor++;
        else
            _proposals[proposalId].votesAgainst++;

        _voters[proposalId].add(_msgSender());

        // Emit the event of the vote
        emit Vote(proposalId, _msgSender(), direction);
    }

    /**
     * Function for managers to execute the proposal's stored calldata upon approval.
     *
     * @param proposalId - The id of the proposal to execute.
     * @return - The status of the proposal, rejected/failed/succeeded.
     */
    function executeProposal(uint256 proposalId) external override returns (Status) {
        // Only managers can execute proposals
        requireManagers(_msgSender());

        // Retrieve proposal into memory
        Proposal memory proposal = _proposals[proposalId];

        // Require that proposal is executable (still pending)
        require(
            proposal.status == Status.PENDING,
            "OpsGovernor: proposal is not pending execution"
        );

        // Require that the proposal is executable (still pending)
        // Require either the deadline is up or more than half have voted in favour
        uint256 numManagers = _managers.length();
        uint256 minVotes = numManagers / 2 + (numManagers % 2 == 0 ? 0 : 1);
        require(
            block.number > proposal.endBlock
            || proposal.votesFor >= minVotes,
            "OpsGovernor: voting is still in progress"
        );

        // Reject if more than or equal AGAINST votes vs FOR votes
        if (proposal.votesFor <= proposal.votesAgainst) {
            _activeProposalsIds.remove(proposalId);
            _proposals[proposalId].status = Status.REJECTED;

            emit ProposalExecuted(proposalId);
            return Status.REJECTED;
        }

        // Perform the call
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(this).call(proposal.callData);

        // Update the status and return it
        if (success) {
            _activeProposalsIds.remove(proposalId);
            _proposals[proposalId].status = Status.APPROVED_AND_EXECUTED;

            emit ProposalExecuted(proposalId);
            return Status.APPROVED_AND_EXECUTED;
        }

        _activeProposalsIds.remove(proposalId);
        _proposals[proposalId].status = Status.APPROVED_BUT_FAILED;

        emit ProposalExecuted(proposalId);
        return Status.APPROVED_BUT_FAILED;
    }

    /**
     * Function to retrieve the total number of proposals in the array.
     *
     * @return - The number of proposals in the array.
     */
    function getNumProposals() external view override returns (uint256) {
        return _proposals.length;
    }

    /**
     * Function to show the proposals that are active for voting.
     *
     * @return proposalIds - The ids of the active proposals.
     */
    function getActiveProposalsIds() external view override returns (uint256[] memory) {
        return _activeProposalsIds.values();
    }

    /**
     * Function to retrieve a proposal based on the input id.
     *
     * @param proposalId - The id of the proposal to fetch.
     * @return - The proposal struct.
     */
    function getProposal(uint256 proposalId) external view override returns (Proposal memory) {
        return _proposals[proposalId];
    }

    /**
     * Function to check whether a proposal is executable now.
     *
     * @param proposalId - The id of the proposal to check.
     * @return - Whether the proposal is executable now.
     */
    function getIsProposalExecutable(
        uint256 proposalId
    ) external override view returns (bool) {
        Proposal memory proposal = _proposals[proposalId];

        // Require that the proposal is executable (still pending)
        // Require either the deadline is up or at least half have voted in favour
        uint256 numManagers = _managers.length();
        uint256 minVotes = numManagers / 2 + (numManagers % 2 == 0 ? 0 : 1);
        return proposal.status == Status.PENDING
            && (
                block.number > proposal.endBlock
                || proposal.votesFor >= minVotes
                || proposal.votesAgainst >= minVotes
            );
    }
}
