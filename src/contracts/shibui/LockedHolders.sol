// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Interfaces
import {ILockedHolders} from "./interfaces/ILockedHolders.sol";

/// @title Holder locking
/// @notice Allows for locking of accounts to prevent them from executing outgoing transfers.
/// @author Shibui (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/shibui/LockedHolders.sol)
contract LockedHolders is ILockedHolders {
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                            HOLDER LOCKING STORAGE                                            ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Address' who cannot transfer tokens.
	mapping(address => bool) public override lockedHolders;

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                        HOLDER STATUS VIEW FUNCTIONS                                           ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Checks if `_holder` is barred from transferring tokens.
	/// @param _holder The target holder address.
	/// @return locked Whether `_holder` is barred from transferring tokens.
	function isLocked(address _holder) public view override returns (bool locked) {
		return lockedHolders[_holder];
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                HOLDER LOCKING FUNCTIONS                                                ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Sets the lock state for `_holder`.
	/// @param _holder The account for which to modify the lock state.
	/// @param _lock The lock state that should be set.
	function setLock(address _holder, bool _lock) internal {
		emit HolderLockUpdated(_holder, _lock, msg.sender);

		lockedHolders[_holder] = _lock;
	}

	////////////////////////////////////////////////////////////////////////////
	///                            HOOK FUNCTIONS                            ///
	////////////////////////////////////////////////////////////////////////////

	/// @dev A hook function that makes sure locked users can't transfer funds.
	function _beforeTokenTransfer(
		address _from,
		address _to,
		uint256 _amount
	) internal virtual {
		require(!isLocked(_from), "HOLDER_LOCKED_FROM_TRANSFER");
		_to;
		_amount;
	}
}
