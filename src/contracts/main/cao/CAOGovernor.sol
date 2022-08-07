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
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Code
import "../../../lib/Decimals.sol";
import "../../../interfaces/main/cao/ICAOGovernor.sol";
import "./CAOToken.sol";

/**
 * @title ICAOGovernor
 * @author Translucent
 *
 * @notice The governor contract for the Centralized Autonomous Organization.
 */
abstract contract CAOGovernor is Context, ICAOGovernor {
    /** Libraries */
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /** Constants */
    uint256 public constant MAX_PROPOSAL_DELAY_BLOCKS = 3 * 28800; // 3 days @ 3 blocks/sec
    uint256 public constant MIN_PROPOSAL_DURATION_BLOCKS = 1200; // 1 hour @ 3 blocks/sec

    /** Governance Parameters */
    uint256 private _advanceExecutionThreshold = 0.5 ether; // 50% in 18 decimals

    /** Governance States */
    CAOToken private _token;
    Proposal[] private _proposals;
    EnumerableSet.UintSet private _activeProposalsIds;
    mapping(uint256 => EnumerableSet.AddressSet) private _voters;
    bool private _isExecuting;

    /** Governance events */
    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event Vote(
        uint256 indexed proposalId,
        address voter,
        Direction direction,
        uint256 votingPower,
        string reason
    );
    event ProposalExecuted(uint256 indexed proposalId);

    /** Constructor */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory initialHolders,
        uint256[] memory initialAmounts
    ) {
        // Require valid input array lengths
        require(
            initialHolders.length == initialAmounts.length,
            "CAOGovernor: invalid array lengths"
        );

        // Token creation
        _token = new CAOToken(name, symbol);
        for (uint i = 0; i < initialHolders.length; i++) {
            _token.mint(initialHolders[i], initialAmounts[i]);
        }
    }

    /*******************************************/
    /** Functions to get details about the CAO */
    /*******************************************/
    function getName() external view override returns (string memory) {
        return _token.name();
    }
    function getCAOTokenAddress() external view override returns (address) {
        return address(_token);
    }

    /**********************************/
    /** Functions to act as modifiers */
    /**********************************/
    /**
     * Function that can be called in a function to ensure that only the
     * CAO is able to call that function, through the governance process.
     *
     * @param caller - The address to check.
     */
    function requireCAOGovernance(address caller) public view override {
        require(
            caller == address(this) // called by the CAO
                && _isExecuting, // updated by `executeProposal()`
            "CAOGovernor: can only be called through governance process"
        );
    }

    /**
     * Function that can be called in a function to ensure that only
     * CAO token holders are able to call that function (emergency cases).
     *
     * @param caller - The adderss to check.
     */
    function requireCAOTokenHolder(address caller) public view override {
        require(
            _token.balanceOf(caller) > 0,
            "CAOGovernor: can only be called by a CAO token holder"
        );
    }

    /**************************************************/
    /** Functions to manage CAO governance parameters */
    /**************************************************/
    function setAdvanceExecutionThreshold(uint256 newThreshold) external override {
        // Only callable by the CAO through governance
        requireCAOGovernance(_msgSender());
        _advanceExecutionThreshold = newThreshold;
    }

    /**************************************************/
    /** Functions to facilitate governance and voting */
    /**************************************************/
    /**
     * Function for holders to create a proposal.
     *
     * @param description - Description about what the proposal is for/about.
     * @param blocksDelay - How long until the voting starts.
     * @param blocksDuration - How long the voting should last.
     * @param callAddresses - The array of addresses to be called upon approval.
     * @param callDatas - The array of calldatas to be executed upon approval.
     * @param callValues - The array of values to be sent upon approval.
     * @return - The id of proposal for voting/execution. 
     */
    function createProposal(
        string memory description,
        uint256 blocksDelay,
        uint256 blocksDuration,
        address[] calldata callAddresses,
        bytes[] calldata callDatas,
        uint256[] calldata callValues
    ) external override returns (uint256) {
        // Require that the caller is currently a holder to create a proposal
        requireCAOTokenHolder(_msgSender());

        // Require that the delay is less than or equal to the max
        require(blocksDelay <= MAX_PROPOSAL_DELAY_BLOCKS, "CAOGovernor: delay is too long");

        // Require the duration is greater than or equal to the min
        require(blocksDuration >= MIN_PROPOSAL_DURATION_BLOCKS, "CAOGovernor: duration is too short");

        // Require that array lengths are valid
        require(callAddresses.length == callDatas.length, "CAOGovernor: invalid call input lengths");
        require(callAddresses.length == callValues.length, "CAOGovernor: invalid call input lengths");

        // Get the proposal ID as the index of the array
        uint256 proposalId = _proposals.length;

        // Track this as an active proposal
        _activeProposalsIds.add(proposalId);

        // Create the proposal struct
        _proposals.push(
            Proposal({
                proposer: _msgSender(),
                description: description,
                startBlock: block.number + blocksDelay,
                endBlock: block.number + blocksDelay + blocksDuration,
                callAddresses: callAddresses,
                callDatas: callDatas,
                callValues: callValues,
                votesFor: 0,
                votesAgainst: 0,
                status: Status.PENDING,
                blockExecuted: 0,
                returnDatas: new bytes[](callAddresses.length)
            })
        );

        // Emit the event of a proposal being created
        emit ProposalCreated(proposalId, _msgSender(), description);

        return proposalId;
    }

    /**
     * Function for holders to cast their votes on a proposal.
     *
     * @param proposalId - The id of the proposal to vote on.
     * @param direction - The vote direction of FOR or AGAINST.
     * @param reason - The reason for the decision.
     */
    function vote(
        uint256 proposalId,
        Direction direction,
        string memory reason
    ) external override {
        // Retrieve the proposal into memory 
        Proposal memory proposal = _proposals[proposalId];

        // Require the caller has the power to vote
        uint256 votingPower = _token.getPastVotes(_msgSender(), proposal.startBlock);
        require(
            votingPower > 0,
            "CAOGovernor: caller has no voting power at start of proposal, check if delegated"
        );

        // Require that voting has started
        require(
            block.number >= proposal.startBlock,
            "CAOGovernor: voting has not started"
        );

        // Require that voting has not ended yet
        require(
            block.number <= proposal.endBlock,
            "CAOGovernor: voting has ended"
        );

        // Require that voter has not voted
        require(
            !_voters[proposalId].contains(_msgSender()),
            "CAOGovernor: caller has already voted"
        );

        // Record the vote
        if (direction == Direction.FOR)
            _proposals[proposalId].votesFor += votingPower;
        else
            _proposals[proposalId].votesAgainst += votingPower;

        _voters[proposalId].add(_msgSender());

        // Emit the event of the vote
        emit Vote(proposalId, _msgSender(), direction, votingPower, reason);
    }

    /**
     * Function for holders to execute the proposal upon approval.
     *
     * @param proposalId - The id of the proposal to execute.
     * @return - The status of the proposal, rejected/failed/succeeded.
     */
    function executeProposal(uint256 proposalId) external override returns (Status) {
        // Retrieve the reference to the proposal
        Proposal storage proposal = _proposals[proposalId];

        // Require that the caller is currently a token holder to execute
        requireCAOTokenHolder(_msgSender());

        // Require that the proposal is executable (still pending)
        require(
            proposal.status == Status.PENDING,
            "CAOGovernor: proposal is not pending execution"
        );

        // Require either the deadline is up or more than half have voted in favour
        uint256 minVotes = _token.getPastTotalSupply(proposal.startBlock) / 2;
        require(
            block.number > proposal.endBlock
                || proposal.votesFor > minVotes
                || proposal.votesAgainst > minVotes,
            "CAOGovernor: voting is still in progress"
        );

        // Reject if more than or equal AGAINST votes vs FOR votes
        if (proposal.votesFor <= proposal.votesAgainst) {
            proposal.status = Status.REJECTED;
            _activeProposalsIds.remove(proposalId);
            proposal.blockExecuted = block.number;

            emit ProposalExecuted(proposalId);
            return Status.REJECTED;
        }

        // Set executing to true
        _isExecuting = true;

        // Perform the calls (first load into memory)
        address[] memory callAddresses = proposal.callAddresses;
        bytes[] memory callDatas = proposal.callDatas;
        uint256[] memory callValues = proposal.callValues;

        for (uint i = 0; i < callAddresses.length; i++) {

            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returnData) = callAddresses[i].call
                { value: callValues[i] }(callDatas[i]);

            // Record the return data and continue
            if (success) {
                proposal.returnDatas[i] = returnData;
                continue;
            }

            // Record the revert message and exit if fail
            proposal.returnDatas[i] = returnData;
            _activeProposalsIds.remove(proposalId);
            proposal.status = Status.APPROVED_BUT_FAILED;
            proposal.blockExecuted = block.number;
            emit ProposalExecuted(proposalId);
            return Status.APPROVED_BUT_FAILED;
        }

        // Set executing back to false
        _isExecuting = false;

        _activeProposalsIds.remove(proposalId);
        proposal.status = Status.APPROVED_AND_EXECUTED;
        proposal.blockExecuted = block.number;

        emit ProposalExecuted(proposalId);
        return Status.APPROVED_AND_EXECUTED;
    }

    /********************************************/
    /** Functions to read the governance states */
    /********************************************/
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
     * @return - The ids of the active proposals.
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
    function getProposal(
        uint256 proposalId
    ) external view override returns (Proposal memory) {
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
        // Require either the deadline is up or more than half have voted in favour
        uint256 minVotes = _token.getPastTotalSupply(proposal.startBlock) / 2;
        return proposal.status == Status.PENDING
            && (
                block.number > proposal.endBlock
                || proposal.votesFor > minVotes
                || proposal.votesAgainst > minVotes
            );
    }
}
