// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

interface IShibui {
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
}
