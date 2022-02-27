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
	// 2,500,000 = 5% of Shibui.
	uint256 public constant QUORUM_VOTES = 2_500_000e18;

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

	/////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                      ALLOWLIST FUNCTIONS                                      ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////

	function isAllowlisted(address _account) public view returns (bool) {
		// solhint-disable-next-line not-rely-on-time
		return (allowlistAccountExpirations[_account] > block.timestamp);
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
