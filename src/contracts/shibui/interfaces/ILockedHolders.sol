// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

/// @author Shibui (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/shibui/interfaces/ILockedHolders.sol)
interface ILockedHolders {
	////////////////////////////////////
	///            EVENTS            ///
	////////////////////////////////////

	/// @notice An event thats emitted when a holder/account gets its lock status updated.
	/// @param account The account being prevented/allowed from transferring, staking, selling, etc... their token.
	/// @param executor Account responsible for this action.
	event HolderLockUpdated(address indexed account, bool indexed status, address executor);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                            HOLDER LOCKING STORAGE                                            ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Address' who cannot transfer tokens.
	function lockedHolders(address acount) external view returns (bool state);

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                        HOLDER STATUS VIEW FUNCTIONS                                           ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Checks if `holder` is barred from transferring tokens.
	/// @param holder The target holder address.
	/// @return locked Whether `holder` is barred from transferring tokens.
	function isLocked(address holder) external view returns (bool locked);
}
