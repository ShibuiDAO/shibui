// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Base contracts
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {LockedHolders} from "./LockedHolders.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IShibui} from "./interfaces/IShibui.sol";

// Structures, libraries, utilities
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title 🌊 Shibui 🌊
/// @notice The ShibuiDAO governance and treasury token.
/// @author Shibui (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/shibui/Shibui.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol)
/// @author Modified from Alchemist (https://github.com/alchemistcoin/alchemist/blob/main/contracts/alchemist/Alchemist.sol)
contract Shibui is ERC20("Shibui", unicode"🌊"), EIP712, ERC20Burnable, ERC20Snapshot, ERC20Permit("Shibui"), LockedHolders, Ownable, IShibui {
	//////////////////////////////////////////////////////////////////////////////////////
	///                                EIP712 CONSTANTS                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	/// @notice The EIP-712 typehash for the delegation struct used by the contract.
	bytes32 public constant override _DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

	///////////////////////////////////////////////////////////////////////////////
	///                                CONSTANTS                                ///
	///////////////////////////////////////////////////////////////////////////////

	/// @notice A constant defining the max supply for "Shibui" (🌊).
	uint96 public constant override MAX_SUPPLY = 50_000_000e18;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                    GOVERNANCE RELATED STORAGE                                                    ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice A record of each accounts delegate.
	mapping(address => address) public override delegates;

	/// @dev A record of votes checkpoints for each account, by index.
	mapping(address => mapping(uint32 => Checkpoint)) internal _checkpoints;

	/// @notice A record of votes checkpoints for each account, by index.
	/// @dev A getter for "_checkpoints".
	/// @param _account Account for which to check the checkpoints.
	/// @param _index The index at which to check for a checkpoint for `_account`.
	/// @return checkpoint Checkpoint found at `_index` for `_account`.
	function checkpoints(address _account, uint32 _index) public view override returns (Checkpoint memory checkpoint) {
		return _checkpoints[_account][_index];
	}

	/// @notice The number of checkpoints for each account.
	mapping(address => uint32) public override numCheckpoints;

	////////////////////////////////////////////////////////////////////////////
	///                            INITIALIZATION                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @notice Mints the max token supply to `_recipient`.
	/// @dev Can only be ran once and alone as calling "mintAmount" would prevent this from starting at 0.
	///      For UX purposes the functions prevents minting to address(0).
	/// @param _recipient The account getting minted the whole initial token supply to distribute.
	function mintFull(address _recipient) external onlyOwner {
		require(_recipient != address(0), "MINT_BURN");
		require(totalSupply() == 0, "MINT_EXECUTED");

		ERC20._mint(_recipient, MAX_SUPPLY);
	}

	/// @notice Mints a specific amount (`_amount`) of "Shibui" (🌊) to `_recipient`.
	/// @dev Can only be used if the total supply is below max supply and if the future supply is below max supply.
	///      For UX purposes the functions prevents minting to address(0).
	/// @param _recipient The account to which to mint.
	/// @param _amount The amount of tokens to mint.
	function mintAmount(address _recipient, uint96 _amount) external onlyOwner {
		require(_recipient != address(0), "MINT_BURN");
		require(totalSupply() <= MAX_SUPPLY, "MINT_COMPLETED");
		require((totalSupply() + _amount) <= MAX_SUPPLY, "MINT_WOULD_EXCEED");

		ERC20._mint(_recipient, _amount);
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                  USER DELEGATION FUNCTIONS                                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Delegate votes from `msg.sender` to `delegatee`.
	/// @param _delegatee The address to delegate votes to.
	function delegate(address _delegatee) external override {
		return _delegate(msg.sender, _delegatee);
	}

	/// @notice Delegates votes from signatory to `delegatee`.
	/// @param _delegatee The address to delegate votes to.
	/// @param _nonce The contract state required to match the signature.
	/// @param _expiry The time at which to expire the signature.
	/// @param _v The recovery byte of the signature.
	/// @param _r Half of the ECDSA signature pair.
	/// @param _s Half of the ECDSA signature pair.
	function delegateBySig(
		address _delegatee,
		uint256 _nonce,
		uint256 _expiry,
		uint8 _v,
		bytes32 _r,
		bytes32 _s
	) external override {
		bytes32 structHash = keccak256(abi.encode(_DELEGATION_TYPEHASH, _delegatee, _nonce, _expiry));
		bytes32 hash = _hashTypedDataV4(structHash);

		address signer = ECDSA.recover(hash, _v, _r, _s);

		require(signer != address(0), "DELEGATE_SIG_INVALID_SIG");
		require(_nonce == _useNonce(signer), "DELEGATE_SIG_INVALID_NONCE");
		// solhint-disable-next-line not-rely-on-time
		require(block.timestamp <= _expiry, "DELEGATE_SIG_EXPIRED");

		return _delegate(signer, _delegatee);
	}

	////////////////////////////////////////////////////////////////////////////
	///                            VOTE FUNCTIONS                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @notice Gets the current votes balance for `account`.
	/// @param _account The address to get votes balance.
	/// @return votes The number of current votes for `account`.
	function getCurrentVotes(address _account) external view override returns (uint96 votes) {
		uint32 nCheckpoints = numCheckpoints[_account];
		return nCheckpoints > 0 ? _checkpoints[_account][nCheckpoints - 1].votes : 0;
	}

	/// @notice Determine the prior number of votes for an account as of a block number.
	/// @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
	/// @param _account The address of the account to check.
	/// @param _blockNumber The block number to get the vote balance at.
	/// @return votes The number of votes the account had as of the given block.
	function getPriorVotes(address _account, uint256 _blockNumber) external view override returns (uint96 votes) {
		require(_blockNumber < block.number, "VOTES_NOT_YET_DETERMINED");

		uint32 nCheckpoints = numCheckpoints[_account];
		if (nCheckpoints == 0) {
			return 0;
		}

		// First check most recent balance
		if (_checkpoints[_account][nCheckpoints - 1].fromBlock <= _blockNumber) {
			return _checkpoints[_account][nCheckpoints - 1].votes;
		}

		// Next check implicit zero balance
		if (_checkpoints[_account][0].fromBlock > _blockNumber) {
			return 0;
		}

		uint32 lower = 0;
		uint32 upper = nCheckpoints - 1;
		while (upper > lower) {
			uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
			Checkpoint memory cp = _checkpoints[_account][center];
			if (cp.fromBlock == _blockNumber) {
				return cp.votes;
			} else if (cp.fromBlock < _blockNumber) {
				lower = center;
			} else {
				upper = center - 1;
			}
		}
		return _checkpoints[_account][lower].votes;
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                          INTERNAL DELEGATION FUNCTIONS                                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function _delegate(address _delegator, address _delegatee) internal {
		address currentDelegate = delegates[_delegator];
		uint96 delegatorBalance = SafeCast.toUint96(balanceOf(_delegator));
		delegates[_delegator] = _delegatee;

		emit DelegateChanged(_delegator, currentDelegate, _delegatee);

		_moveDelegates(currentDelegate, _delegatee, delegatorBalance);
	}

	function _moveDelegates(
		address _srcRep,
		address _dstRep,
		uint256 _amount
	) internal {
		if (_srcRep != _dstRep && _amount > 0) {
			if (_srcRep != address(0)) {
				uint32 srcRepNum = numCheckpoints[_srcRep];
				uint96 srcRepOld = srcRepNum > 0 ? _checkpoints[_srcRep][srcRepNum - 1].votes : 0;
				uint96 srcRepNew = SafeCast.toUint96(srcRepOld - _amount);
				_writeCheckpoint(_srcRep, srcRepNum, srcRepOld, srcRepNew);
			}

			if (_dstRep != address(0)) {
				uint32 dstRepNum = numCheckpoints[_dstRep];
				uint96 dstRepOld = dstRepNum > 0 ? _checkpoints[_dstRep][dstRepNum - 1].votes : 0;
				uint96 dstRepNew = SafeCast.toUint96(dstRepOld + _amount);
				_writeCheckpoint(_dstRep, dstRepNum, dstRepOld, dstRepNew);
			}
		}
	}

	function _writeCheckpoint(
		address _delegatee,
		uint32 _nCheckpoints,
		uint256 _oldVotes,
		uint256 _newVotes
	) internal {
		uint32 blockNumber = SafeCast.toUint32(block.number);

		if (_nCheckpoints > 0 && _checkpoints[_delegatee][_nCheckpoints - 1].fromBlock == blockNumber) {
			_checkpoints[_delegatee][_nCheckpoints - 1].votes = SafeCast.toUint96(_newVotes);
		} else {
			_checkpoints[_delegatee][_nCheckpoints] = Checkpoint(blockNumber, SafeCast.toUint96(_newVotes));
			numCheckpoints[_delegatee] = _nCheckpoints + 1;
		}

		emit DelegateVotesChanged(_delegatee, _oldVotes, _newVotes);
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                HOLDER LOCKING FUNCTIONS                                                ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Locks `_holder` from transferring tokens.
	/// @param _holder The target holder address.
	function lockHolder(address _holder) external onlyOwner {
		setLock(_holder, true);
	}

	/// @notice Unlocks `_holder` from transferring tokens.
	/// @param _holder The target holder address.
	function unlockHolder(address _holder) external onlyOwner {
		setLock(_holder, false);
	}

	////////////////////////////////////////////////////////////////////////////
	///                            HOOK FUNCTIONS                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @inheritdoc ERC20
	function _beforeTokenTransfer(
		address _from,
		address _to,
		uint256 _amount
	) internal override(ERC20, ERC20Snapshot, LockedHolders) {
		LockedHolders._beforeTokenTransfer(_from, _to, _amount);

		ERC20Snapshot._beforeTokenTransfer(_from, _to, _amount);
		_moveDelegates(delegates[_from], delegates[_to], _amount);
	}
}
