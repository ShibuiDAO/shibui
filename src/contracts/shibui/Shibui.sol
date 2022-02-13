// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IShibui} from "./IShibui.sol";

/// @title 🌊 Shibui 🌊
/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/shibui/Shibui.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol)
/// @author Modified from Alchemist (https://github.com/alchemistcoin/alchemist/blob/main/contracts/alchemist/Alchemist.sol)
contract Shibui is ERC20("Shibui", unicode"🌊"), EIP712, ERC20Burnable, ERC20Snapshot, ERC20Permit("Shibui"), IShibui {
	/// @notice The EIP-712 typehash for the delegation struct used by the contract
	bytes32 public constant _DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

	/// @notice A record of each accounts delegate.
	mapping(address => address) public delegates;

	/// @notice A record of votes checkpoints for each account, by index.
	mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

	/// @notice The number of checkpoints for each account.
	mapping(address => uint32) public numCheckpoints;

	/*///////////////////////////////////////////////////////////////
                          USER DELEGATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Delegate votes from `msg.sender` to `delegatee`.
	/// @param delegatee The address to delegate votes to.
	function delegate(address delegatee) public {
		return _delegate(msg.sender, delegatee);
	}

	/// @notice Delegates votes from signatory to `delegatee`.
	/// @param delegatee The address to delegate votes to.
	/// @param nonce The contract state required to match the signature.
	/// @param expiry The time at which to expire the signature.
	/// @param v The recovery byte of the signature.
	/// @param r Half of the ECDSA signature pair.
	/// @param s Half of the ECDSA signature pair.
	function delegateBySig(
		address delegatee,
		uint256 nonce,
		uint256 expiry,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public {
		bytes32 structHash = keccak256(abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry));
		bytes32 hash = _hashTypedDataV4(structHash);

		address signer = ECDSA.recover(hash, v, r, s);

		require(signer != address(0), "DELEGATE_SIG_INVALID_SIG");
		require(nonce == _useNonce(signer), "DELEGATE_SIG_INVALID_NONCE");
		// solhint-disable-next-line not-rely-on-time
		require(block.timestamp <= expiry, "DELEGATE_SIG_EXPIRED");

		return _delegate(signer, delegatee);
	}

	/*///////////////////////////////////////////////////////////////
                        INTERNAL DELEGATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function _delegate(address delegator, address delegatee) internal {
		address currentDelegate = delegates[delegator];
		uint256 delegatorBalance = balanceOf(delegator);
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
				uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
				uint256 srcRepNew = srcRepOld - amount;
				_writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
			}

			if (dstRep != address(0)) {
				uint32 dstRepNum = numCheckpoints[dstRep];
				uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
				uint256 dstRepNew = dstRepOld - amount;
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
		uint32 blockNumber = safe32(block.number, "BLOCK_NUMBER_EXCEEDS_32_BITS");

		if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
			checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
		} else {
			checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
			numCheckpoints[delegatee] = nCheckpoints + 1;
		}

		emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
	}

	/*///////////////////////////////////////////////////////////////
                                HOOK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @inheritdoc ERC20
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override(ERC20, ERC20Snapshot) {
		ERC20Snapshot._beforeTokenTransfer(from, to, amount);
		_moveDelegates(delegates[from], delegates[to], amount);
	}

	/*///////////////////////////////////////////////////////////////
                        MATH "POLYFILL" FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
		require(n < 2**32, errorMessage);
		return uint32(n);
	}
}
