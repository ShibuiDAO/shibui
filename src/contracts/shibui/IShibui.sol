// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/shibui/IShibui.sol)
interface IShibui is IERC20, IERC20Permit {
	/*///////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////*/

	/// @notice An event thats emitted when an account changes its delegate.
	event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

	/// @notice An event thats emitted when a delegate account's vote balance changes.
	event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

	/*///////////////////////////////////////////////////////////////
                            VOTE CHECKPOINTING
    //////////////////////////////////////////////////////////////*/

	/// @notice A checkpoint for marking number of votes from a given block.
	struct Checkpoint {
		uint32 fromBlock;
		uint256 votes;
	}

	/*///////////////////////////////////////////////////////////////
                          USER DELEGATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	/// @notice Delegate votes from `msg.sender` to `delegatee`.
	/// @param delegatee The address to delegate votes to.
	function delegate(address delegatee) external;

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
	) external;
}
