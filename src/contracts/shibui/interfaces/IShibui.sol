// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Base contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/// @title "🌊 Shibui 🌊" public interface
/// @notice Inteface describing the functions, events, and structs for the "Shibui" (🌊) governance token.
/// @author Shibui (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/shibui/interfaces/IShibui.sol)
interface IShibui is IERC20, IERC20Permit {
	//////////////////////////////////////////////////////////////////////////////////////
	///                                EIP712 CONSTANTS                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	/// @notice The EIP-712 typehash for the delegation struct used by the contract.
	// solhint-disable-next-line func-name-mixedcase, var-name-mixedcase
	function _DELEGATION_TYPEHASH() external pure returns (bytes32 _DELEGATION_TYPEHASH);

	///////////////////////////////////////////////////////////////////////////////
	///                                CONSTANTS                                ///
	///////////////////////////////////////////////////////////////////////////////

	/// @notice A constant defining the max supply for "Shibui" (🌊).
	// solhint-disable-next-line func-name-mixedcase, var-name-mixedcase
	function MAX_SUPPLY() external pure returns (uint96 MAX_SUPPLY);

	////////////////////////////////////
	///            EVENTS            ///
	////////////////////////////////////

	/// @notice An event thats emitted when an account changes its delegate.
	/// @param delegator The account that is delegating their votes.
	/// @param fromDelegate The account that served as the previous delegate.
	/// @param toDelegate The account serving as the new delegate.
	event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

	/// @notice An event thats emitted when a delegate account's vote balance changes.
	/// @param delegate The account of which the vote balance changed.
	/// @param previousBalance The delegates previously delegated balance.
	/// @param newBalance The delegates new balance.
	event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

	////////////////////////////////////////////////////////////////////////////////////////////////
	///                                    VOTE CHECKPOINTING                                    ///
	////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice A checkpoint for marking number of votes from a given block.
	/// @param fromBlock The block from which the Checkpoint is.
	/// @param votes Number of votes present in checkpoint.
	struct Checkpoint {
		uint32 fromBlock;
		uint96 votes;
	}

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                    GOVERNANCE RELATED STORAGE                                                    ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice A record of each accounts delegate.
	function delegates(address delegator) external view returns (address delegatee);

	/// @notice A record of votes checkpoints for each account, by index.
	function checkpoints(address account, uint32 index) external view returns (Checkpoint memory checkpoint);

	/// @notice The number of checkpoints for each account.
	function numCheckpoints(address account) external view returns (uint32 number);

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                  USER DELEGATION FUNCTIONS                                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

	////////////////////////////////////////////////////////////////////////////
	///                            VOTE FUNCTIONS                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @notice Gets the current votes balance for `account`.
	/// @param account The address to get votes balance.
	/// @return votes The number of current votes for `account`.
	function getCurrentVotes(address account) external view returns (uint96 votes);

	/// @notice Determine the prior number of votes for an account as of a block number.
	/// @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
	/// @param account The address of the account to check.
	/// @param blockNumber The block number to get the vote balance at.
	/// @return votes The number of votes the account had as of the given block.
	function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96 votes);
}
