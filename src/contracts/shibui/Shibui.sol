// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Base contracts
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IShibui} from "./IShibui.sol";

// Structures, libraries, utilities
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title 🌊 Shibui 🌊
/// @notice The ShibuiDAO governance and treasury token.
/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/shibui/Shibui.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol)
/// @author Modified from Alchemist (https://github.com/alchemistcoin/alchemist/blob/main/contracts/alchemist/Alchemist.sol)
contract Shibui is ERC20("Shibui", unicode"🌊"), EIP712, ERC20Burnable, ERC20Snapshot, ERC20Permit("Shibui"), Ownable, IShibui {
	//////////////////////////////////////////////////////////////////////////////////////
	///                                EIP712 CONSTANTS                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	/// @notice The EIP-712 typehash for the delegation struct used by the contract
	bytes32 public constant _DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                    GOVERNANCE RELATED STORAGE                                                    ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice A record of each accounts delegate.
	mapping(address => address) public delegates;

	/// @notice A record of votes checkpoints for each account, by index.
	mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

	/// @notice The number of checkpoints for each account.
	mapping(address => uint32) public numCheckpoints;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                            HOLDER LOCKING STORAGE                                            ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Address' who cannot transfer tokens.
	mapping(address => bool) public lockedHolders;

	////////////////////////////////////
	///            EVENTS            ///
	////////////////////////////////////

	/// @notice An event thats emitted when a holder/account gets locked from transferring their tokens.
	/// @param account The account being prevented from transferring, staking, selling, etc... their token.
	/// @param executor Account responsible for this action.
	event HolderLocked(address indexed account, address indexed executor);

	/// @notice An event thats emitted when a holder/account gets unlocked from transferring their tokens.
	/// @param account The account being removed from the lockedHolders mapping.
	/// @param executor Account responsible for this action.
	event HolderUnlocked(address indexed account, address indexed executor);

	////////////////////////////////////////////////////////////////////////////
	///                            INITIALIZATION                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @param _recipient The account getting minted the whole initial token supply to distribute.
	constructor(address _recipient) {
		// mint initial supply
		ERC20._mint(_recipient, 50_000_000e18); // 50 million
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                  USER DELEGATION FUNCTIONS                                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Delegate votes from `msg.sender` to `delegatee`.
	/// @param delegatee The address to delegate votes to.
	/// @inheritdoc IShibui
	function delegate(address delegatee) public override {
		return _delegate(msg.sender, delegatee);
	}

	/// @notice Delegates votes from signatory to `delegatee`.
	/// @param delegatee The address to delegate votes to.
	/// @param nonce The contract state required to match the signature.
	/// @param expiry The time at which to expire the signature.
	/// @param v The recovery byte of the signature.
	/// @param r Half of the ECDSA signature pair.
	/// @param s Half of the ECDSA signature pair.
	/// @inheritdoc IShibui
	function delegateBySig(
		address delegatee,
		uint256 nonce,
		uint256 expiry,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public override {
		bytes32 structHash = keccak256(abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry));
		bytes32 hash = _hashTypedDataV4(structHash);

		address signer = ECDSA.recover(hash, v, r, s);

		require(signer != address(0), "DELEGATE_SIG_INVALID_SIG");
		require(nonce == _useNonce(signer), "DELEGATE_SIG_INVALID_NONCE");
		// solhint-disable-next-line not-rely-on-time
		require(block.timestamp <= expiry, "DELEGATE_SIG_EXPIRED");

		return _delegate(signer, delegatee);
	}

	////////////////////////////////////////////////////////////////////////////
	///                            VOTE FUNCTIONS                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @notice Gets the current votes balance for `account`.
	/// @param account The address to get votes balance.
	/// @return The number of current votes for `account`.
	/// @inheritdoc IShibui
	function getCurrentVotes(address account) external view override returns (uint96) {
		uint32 nCheckpoints = numCheckpoints[account];
		return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
	}

	/// @notice Determine the prior number of votes for an account as of a block number.
	/// @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
	/// @param account The address of the account to check.
	/// @param blockNumber The block number to get the vote balance at.
	/// @return The number of votes the account had as of the given block.
	/// @inheritdoc IShibui
	function getPriorVotes(address account, uint256 blockNumber) public view override returns (uint96) {
		require(blockNumber < block.number, "VOTES_NOT_YET_DETERMINED");

		uint32 nCheckpoints = numCheckpoints[account];
		if (nCheckpoints == 0) {
			return 0;
		}

		// First check most recent balance
		if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
			return checkpoints[account][nCheckpoints - 1].votes;
		}

		// Next check implicit zero balance
		if (checkpoints[account][0].fromBlock > blockNumber) {
			return 0;
		}

		uint32 lower = 0;
		uint32 upper = nCheckpoints - 1;
		while (upper > lower) {
			uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
			Checkpoint memory cp = checkpoints[account][center];
			if (cp.fromBlock == blockNumber) {
				return cp.votes;
			} else if (cp.fromBlock < blockNumber) {
				lower = center;
			} else {
				upper = center - 1;
			}
		}
		return checkpoints[account][lower].votes;
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                          INTERNAL DELEGATION FUNCTIONS                                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function _delegate(address delegator, address delegatee) internal {
		address currentDelegate = delegates[delegator];
		uint96 delegatorBalance = SafeCast.toUint96(balanceOf(delegator));
		delegates[delegator] = delegatee;

		emit DelegateChanged(delegator, currentDelegate, delegatee);

		_moveDelegates(currentDelegate, delegatee, delegatorBalance);
	}

	function _moveDelegates(
		address srcRep,
		address dstRep,
		uint256 amount
	) internal {
		if (srcRep != dstRep && amount > 0) {
			if (srcRep != address(0)) {
				uint32 srcRepNum = numCheckpoints[srcRep];
				uint96 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
				uint96 srcRepNew = SafeCast.toUint96(srcRepOld - amount);
				_writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
			}

			if (dstRep != address(0)) {
				uint32 dstRepNum = numCheckpoints[dstRep];
				uint96 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
				uint96 dstRepNew = SafeCast.toUint96(dstRepOld + amount);
				_writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
			}
		}
	}

	function _writeCheckpoint(
		address delegatee,
		uint32 nCheckpoints,
		uint256 oldVotes,
		uint256 newVotes
	) internal {
		uint32 blockNumber = SafeCast.toUint32(block.number);

		if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
			checkpoints[delegatee][nCheckpoints - 1].votes = SafeCast.toUint96(newVotes);
		} else {
			checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, SafeCast.toUint96(newVotes));
			numCheckpoints[delegatee] = nCheckpoints + 1;
		}

		emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                HOLDER LOCKING FUNCTIONS                                                ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Checks if `_holder` is barred from transferring tokens.
	/// @param _holder The target holder address.
	/// @return Whether `_holder` is barred from transferring tokens.
	function isLocked(address _holder) public view virtual returns (bool) {
		return lockedHolders[_holder];
	}

	/// @notice Locks `_holder` from transferring tokens.
	/// @param _holder The target holder address.
	function lockHolder(address _holder) public onlyOwner {
		emit HolderLocked(_holder, _msgSender());

		lockedHolders[_holder] = true;
	}

	/// @notice Unlocks `_holder` from transferring tokens.
	/// @param _holder The target holder address.
	function unlockHolder(address _holder) public onlyOwner {
		emit HolderUnlocked(_holder, _msgSender());

		lockedHolders[_holder] = false;
	}

	////////////////////////////////////////////////////////////////////////////
	///                            HOOK FUNCTIONS                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @inheritdoc ERC20
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override(ERC20, ERC20Snapshot) {
		require(!isLocked(from), "HOLDER_LOCKED_FROM_TRANSFER");

		ERC20Snapshot._beforeTokenTransfer(from, to, amount);
		_moveDelegates(delegates[from], delegates[to], amount);
	}
}
