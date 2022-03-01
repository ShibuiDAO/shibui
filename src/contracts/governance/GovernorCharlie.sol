// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Base contracts
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

// Interfaces
import {IGovernorCharlie} from "./interfaces/IGovernorCharlie.sol";
import {ITimelock} from "./interfaces/ITimelock.sol";
import {IShibui} from "../shibui/interfaces/IShibui.sol";

// Structures, libraries, utilities
import {SafeCastUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

/// @title Governor Charlie
/// @dev This is centred around Boba so some out-of-place tweaks were made.
/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/governance/GovernorCharlie.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorBravoDelegate.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorBravoInterfaces.sol)
contract GovernorCharlie is Initializable, ContextUpgradeable, OwnableUpgradeable, EIP712Upgradeable, IGovernorCharlie {
	using SafeCastUpgradeable for uint256;

	//////////////////////////////////////////////////////////////////////////////////////
	///                                EIP712 CONSTANTS                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	bytes32 public constant _BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

	bytes32 public constant _BALLOT_REASON_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support,string reason)");

	///////////////////////////////////////////////////////////////////////////////////////////
	///                                  CONTRACT METADATA                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////

	// solhint-disable-next-line const-name-snakecase
	string public constant name = "Shibui Governor Charlie";

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                  GOVERNANCE PROCESS LIMITS                                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice The minimum setable voting period.
	uint256 public constant MIN_VOTING_PERIOD = 24 hours;

	/// @notice The max setable voting period.
	uint256 public constant MAX_VOTING_PERIOD = 14 days;

	/// @notice The min setable voting delay.
	uint256 public constant MIN_VOTING_DELAY = 1;

	/// @notice The max setable voting delay.
	/// @dev Boba produces blocks quite irregularly so this value is just a shot in the dark. It presumes 1 block a second so the max delay is 7 days.
	uint256 public constant MAX_VOTING_DELAY = 604_800;

	/// @notice The minimum setable proposal threshold.
	/// @dev 250,00 Shibui.
	uint256 public constant MIN_PROPOSAL_THRESHOLD = 250_000e18;

	/// @notice The maximum setable proposal threshold.
	/// @dev 500,000 Shibui;
	uint256 public constant MAX_PROPOSAL_THRESHOLD = 500_000e18;

	/// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed.
	/// @dev 2,500,000 = 5% of Shibui.
	uint256 public constant QUORUM_VOTES = 2_500_000e18;

	/// @notice The maximum number of actions that can be included in a proposal
	/// @dev 10 actions.
	uint256 public constant PROPOSAL_MAX_OPERATIONS = 10;

	////////////////////////////////////////////////////////////////////////////////////////////////
	///                                    GOVERNOR PERIPHERY                                    ///
	////////////////////////////////////////////////////////////////////////////////////////////////

	ITimelock public timelock;

	IShibui public shibui;

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                          GOVERNANCE PROCESS PARAMETERS                                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice The duration of voting on a proposal, in seconds.
	uint256 public votingPeriod;

	/// @notice The delay before voting on a proposal may take place, once proposed, in blocks.
	uint256 public votingDelay;

	/// @notice The number of votes required in order for a voter to become a proposer.
	uint256 public proposalThreshold;

	/// @notice Initial proposal id set at "initiateGovernance".
	uint256 public initialProposalId;

	//////////////////////////////////////////////////////////////////////////////////////
	///                                PROPOSAL STORAGE                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	/// @notice The total number of proposals.
	uint256 public proposalCount;

	/// @notice The official record of all proposals ever proposed.
	mapping(uint256 => Proposal) public proposals;

	/// @notice The latest proposal for each proposer.
	mapping(address => uint256) public latestProposalIds;

	///////////////////////////////////////////////////////////////////////////////////////////
	///                                  ALLOWLIST STORAGE                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Address which manages allowed proposals and allowlists accounts.
	address public allowlistGuardian;

	/// @notice Stores the expiration of an accounts allowlist status as a timestamp.
	mapping(address => uint256) public allowlistAccountExpirations;

	//////////////////////////////////////////////////////////////////////////////////////////////////
	///                    UPGRADEABLE CONTRACT INITIALIZER/CONTRUCTOR FUNCTION                    ///
	//////////////////////////////////////////////////////////////////////////////////////////////////

	/// @dev Never called.
	/// @custom:oz-upgrades-unsafe-allow constructor
	// solhint-disable-next-line no-empty-blocks
	constructor() initializer {}

	// solhint-disable-next-line func-name-mixedcase
	function __GovernorCharlie_init(
		address _timelock,
		address _shibui,
		uint256 _votingPeriod,
		uint256 _votingDelay,
		uint256 _proposalThreshold
	) internal initializer {
		__Context_init();
		__Ownable_init();
		__EIP712_init(name, version());
		__GovernorCharlie_init_unchained(_timelock, _shibui, _votingPeriod, _votingDelay, _proposalThreshold);
	}

	// solhint-disable-next-line func-name-mixedcase
	function __GovernorCharlie_init_unchained(
		address _timelock,
		address _shibui,
		uint256 _votingPeriod,
		uint256 _votingDelay,
		uint256 _proposalThreshold
	) internal onlyInitializing {
		require(_timelock != address(0), "TIMELOCK_ADDRESS_INVALID");
		require(_shibui != address(0), "SHIBUI_ADDRESS_INVALID");
		require(_votingPeriod >= MIN_VOTING_PERIOD && _votingPeriod <= MAX_VOTING_PERIOD, "VOTING_PERIOD_INVALID");
		require(_votingDelay >= MIN_VOTING_DELAY && _votingDelay <= MAX_VOTING_DELAY, "VOTING_DELAY_INVALID");
		require(_proposalThreshold >= MIN_PROPOSAL_THRESHOLD && _proposalThreshold <= MAX_PROPOSAL_THRESHOLD, "PROPOSAL_THRESHOLD_INVALID");

		timelock = ITimelock(_timelock);
		shibui = IShibui(_shibui);

		votingPeriod = _votingPeriod;
		votingDelay = _votingDelay;
		proposalThreshold = _proposalThreshold;
	}

	function govern(uint256 _initialId) external onlyOwner {
		require(initialProposalId == 0, "INITIATED");
		initialProposalId = _initialId;
		timelock.proposedOwnerAccept();
		_transferOwnership(address(timelock));
	}

	///////////////////////////////////////////////////
	///                  MODIFIERS                  ///
	///////////////////////////////////////////////////

	modifier onlyAllowlistGuardians() {
		require(owner() == _msgSender() || allowlistGuardian == _msgSender(), "CALLER_NOT_PERMITTED");
		_;
	}

	modifier whenGovernorActive() {
		require(initialProposalId != 0, "GOVERNOR_NOT_ACTIVE");
		_;
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                  PROPOSAL PUBLIC FUNCTIONS                                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function propose(
		address[] memory targets,
		uint256[] memory values,
		string[] memory signatures,
		bytes[] memory calldatas,
		string memory description
	) public whenGovernorActive returns (uint256) {
		// Allow addresses above proposal threshold and whitelisted addresses to propose
		require(shibui.getPriorVotes(msg.sender, block.number - 1) > proposalThreshold || isAllowlisted(msg.sender), "PROPOSER_BELOW_THRESHOLD");
		require(
			targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length,
			"INFORMATION_ARITY_MISSMATCH"
		);
		require(targets.length != 0, "ACTIONS_NOT_PROVIDED");
		require(targets.length <= PROPOSAL_MAX_OPERATIONS, "ACTIONS_EXCEED");

		{
			uint256 latestProposalId = latestProposalIds[msg.sender];
			if (latestProposalId != 0) {
				ProposalState proposersLatestProposalState = state(latestProposalId);
				require(proposersLatestProposalState != ProposalState.Active, "PROPOSER_PROPOSING");
				require(proposersLatestProposalState != ProposalState.Pending, "PROPOSER_PROPOSING");
			}
		}

		proposalCount++;
		{
			// solhint-disable-next-line not-rely-on-time
			uint256 timestamp = block.timestamp;
			uint256 startBlock = block.number + votingDelay;
			uint256 endTimestamp = timestamp + votingPeriod;

			Proposal storage newProposal = proposals[proposalCount];

			newProposal.id = proposalCount;
			newProposal.proposer = msg.sender;
			newProposal.eta = 0;
			newProposal.targets = targets;
			newProposal.values = values;
			newProposal.signatures = signatures;
			newProposal.calldatas = calldatas;
			newProposal.timestamp = timestamp;
			newProposal.startBlock = startBlock;
			newProposal.endTimestamp = endTimestamp;
			newProposal.forVotes = 0;
			newProposal.againstVotes = 0;
			newProposal.abstainVotes = 0;
			newProposal.canceled = false;
			newProposal.executed = false;

			latestProposalIds[newProposal.proposer] = newProposal.id;

			emit ProposalCreated(
				newProposal.id,
				msg.sender,
				targets,
				values,
				signatures,
				calldatas,
				timestamp,
				startBlock,
				endTimestamp,
				description
			);
		}

		return proposalCount;
	}

	function cancel(uint256 proposalId) external {
		require(state(proposalId) != ProposalState.Executed, "PROPOSAL_EXECUTED");

		Proposal storage proposal = proposals[proposalId];

		// Proposer can cancel
		if (msg.sender != proposal.proposer) {
			// Allowlisted proposers can't be canceled for falling below proposal threshold
			if (isAllowlisted(proposal.proposer)) {
				require(
					(shibui.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold) && msg.sender == allowlistGuardian,
					"PROPOSER_ALLOWLISTED"
				);
			} else {
				require((shibui.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold), "PROPOSER_ABOVE_THRESHOLD");
			}
		}

		proposal.canceled = true;
		for (uint256 i = 0; i < proposal.targets.length; i++) {
			timelock.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
		}

		emit ProposalCanceled(proposalId);
	}

	function queue(uint256 _proposalId) external {
		require(state(_proposalId) == ProposalState.Succeeded, "PROPOSAL_NOT_SUCCEEDED");

		Proposal storage proposal = proposals[_proposalId];
		// solhint-disable-next-line not-rely-on-time
		uint256 eta = block.timestamp + timelock.delay();

		for (uint256 i = 0; i < proposal.targets.length; i++) {
			_queueOrRevert(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);
		}

		proposal.eta = eta;

		emit ProposalQueued(_proposalId, eta);
	}

	function execute(uint256 _proposalId) external payable {
		require(state(_proposalId) == ProposalState.Queued, "PROPOSAL_NOT_QUEUED");

		Proposal storage proposal = proposals[_proposalId];
		proposal.executed = true;

		for (uint256 i = 0; i < proposal.targets.length; i++) {
			timelock.executeTransaction{value: proposal.values[i]}(
				proposal.targets[i],
				proposal.values[i],
				proposal.signatures[i],
				proposal.calldatas[i],
				proposal.eta
			);
		}

		emit ProposalExecuted(_proposalId);
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                              PROPOSAL VIEW FUNCTIONS                                              ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function getActions(uint256 _proposalId)
		external
		view
		returns (
			address[] memory targets,
			uint256[] memory values,
			string[] memory signatures,
			bytes[] memory calldatas
		)
	{
		Proposal storage p = proposals[_proposalId];
		return (p.targets, p.values, p.signatures, p.calldatas);
	}

	function getReceipt(uint256 _proposalId, address _voter) external view returns (Receipt memory) {
		return proposals[_proposalId].receipts[_voter];
	}

	function state(uint256 _proposalId) public view returns (ProposalState) {
		require(proposalCount >= _proposalId && _proposalId > initialProposalId, "PROPOSAL_ID_INVALID");
		Proposal storage proposal = proposals[_proposalId];
		if (proposal.canceled) {
			return ProposalState.Canceled;
		} else if (block.number <= proposal.startBlock) {
			return ProposalState.Pending;
			// solhint-disable-next-line not-rely-on-time
		} else if (block.timestamp <= proposal.endTimestamp) {
			return ProposalState.Active;
		} else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < QUORUM_VOTES) {
			return ProposalState.Defeated;
		} else if (proposal.eta == 0) {
			return ProposalState.Succeeded;
		} else if (proposal.executed) {
			return ProposalState.Executed;
			// solhint-disable-next-line not-rely-on-time
		} else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
			return ProposalState.Expired;
		} else {
			return ProposalState.Queued;
		}
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                      PROPOSAL INTERNAL FUNCTIONS                                                      ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function _queueOrRevert(
		address _target,
		uint256 _value,
		string memory _signature,
		bytes memory _data,
		uint256 _eta
	) internal {
		require(!timelock.queuedTransactions(keccak256(abi.encode(_target, _value, _signature, _data, _eta))), "PROPOSAL_QUEUED_ETA");
		timelock.queueTransaction(_target, _value, _signature, _data, _eta);
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                          VOTE PUBLIC FUNCTIONS                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function castVote(uint256 _proposalId, uint8 _support) external {
		emit VoteCast(_msgSender(), _proposalId, _support, _castVote(_msgSender(), _proposalId, _support), "");
	}

	function castVoteWithReason(
		uint256 _proposalId,
		uint8 _support,
		string calldata _reason
	) external {
		emit VoteCast(_msgSender(), _proposalId, _support, _castVote(_msgSender(), _proposalId, _support), _reason);
	}

	function castVoteBySig(
		uint256 _proposalId,
		uint8 _support,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external {
		bytes32 structHash = keccak256(abi.encode(_BALLOT_TYPEHASH, _proposalId, _support));
		bytes32 hash = _hashTypedDataV4(structHash);

		address signer = ECDSAUpgradeable.recover(hash, v, r, s);
		require(signer != address(0), "SIGNATURE_INVALID");

		emit VoteCast(signer, _proposalId, _support, _castVote(signer, _proposalId, _support), "");
	}

	function castVoteWithReasonBySig(
		uint256 _proposalId,
		uint8 _support,
		string calldata _reason,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external {
		bytes32 structHash = keccak256(abi.encode(_BALLOT_REASON_TYPEHASH, _proposalId, _support, _reason));
		bytes32 hash = _hashTypedDataV4(structHash);

		address signer = ECDSAUpgradeable.recover(hash, v, r, s);
		require(signer != address(0), "SIGNATURE_INVALID");

		emit VoteCast(signer, _proposalId, _support, _castVote(signer, _proposalId, _support), _reason);
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                              VOTE INTERNAL FUNCTIONS                                              ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function _castVote(
		address _voter,
		uint256 _proposalId,
		uint8 _support
	) internal returns (uint96) {
		require(state(_proposalId) == ProposalState.Active, "VOTING_CLOSED");
		require(_support <= 2, "VOTE_TYPE_INVALID");
		Proposal storage proposal = proposals[_proposalId];
		Receipt storage receipt = proposal.receipts[_voter];
		require(receipt.hasVoted == false, "VOTER_VOTED");
		uint96 votes = shibui.getPriorVotes(_voter, proposal.startBlock);

		if (_support == 0) {
			proposal.againstVotes += votes;
		} else if (_support == 1) {
			proposal.forVotes += votes;
		} else if (_support == 2) {
			proposal.abstainVotes += votes;
		}

		receipt.hasVoted = true;
		receipt.support = _support;
		receipt.votes = votes;

		return votes;
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                                        GOVERNANCE PROCESS CONTROL FUNCTIONS                                                                        ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function setVotingPeriod(uint256 _newVotingPeriod) external onlyOwner {
		require(_newVotingPeriod >= MIN_VOTING_PERIOD && _newVotingPeriod <= MAX_VOTING_PERIOD, "VOTING_PERIOD_INVALID");
		uint256 oldVotingPeriod = votingPeriod;
		votingPeriod = _newVotingPeriod;

		emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
	}

	function setVotingDelay(uint256 _newVotingDelay) external onlyOwner {
		require(_newVotingDelay >= MIN_VOTING_DELAY && _newVotingDelay <= MAX_VOTING_DELAY, "VOTING_DELAY_INVALID");
		uint256 oldVotingDelay = votingDelay;
		votingDelay = _newVotingDelay;

		emit VotingDelaySet(oldVotingDelay, votingDelay);
	}

	function setProposalThreshold(uint256 _newProposalThreshold) external onlyOwner {
		require(_newProposalThreshold >= MIN_PROPOSAL_THRESHOLD && _newProposalThreshold <= MAX_PROPOSAL_THRESHOLD, "PROPOSAL_THRESHOLD_INVALID");
		uint256 oldProposalThreshold = proposalThreshold;
		proposalThreshold = _newProposalThreshold;

		emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
	}

	/////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                      ALLOWLIST FUNCTIONS                                      ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////

	function isAllowlisted(address _account) public view returns (bool) {
		// solhint-disable-next-line not-rely-on-time
		return (allowlistAccountExpirations[_account] > block.timestamp);
	}

	/// @dev A compatibility function to follow GovernorBravo.
	function isWhitelisted(address _account) public view returns (bool) {
		return isAllowlisted(_account);
	}

	function setAllowlistAccountExpiration(address _account, uint256 _expiration) external onlyAllowlistGuardians {
		allowlistAccountExpirations[_account] = _expiration;

		emit AllowlistAccountExpirationSet(_account, _expiration);
	}

	function setAllowlistGuardian(address _account) external onlyOwner {
		address oldGuardian = allowlistGuardian;
		allowlistGuardian = _account;

		emit AllowlistGuardianSet(oldGuardian, allowlistGuardian);
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                          INFORMATIVE FUNCTIONS                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function version() public pure returns (string memory) {
		return "1";
	}
}
