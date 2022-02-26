// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/governance/interfaces/ITimelock.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Timelock.sol)
/// @author Modified from Alchemist (https://github.com/alchemistcoin/alchemist/blob/main/contracts/alchemist/TimelockConfig.sol)
interface ITimelock {
	////////////////////////////////////
	///            EVENTS            ///
	////////////////////////////////////

	event NewDelay(uint256 indexed newDelay);
	event CancelTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
	event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);
	event QueueTransaction(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 eta);

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                TIMELOCK ADMIN FUNCTIONS                                                ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function setDelay(uint256 delay_) external;

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                          TRANSACTION FUNCTIONS                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function queueTransaction(
		address target,
		uint256 value,
		string calldata signature,
		bytes calldata data,
		uint256 eta
	) external returns (bytes32);

	function cancelTransaction(
		address target,
		uint256 value,
		string calldata signature,
		bytes calldata data,
		uint256 eta
	) external;

	function executeTransaction(
		address target,
		uint256 value,
		string calldata signature,
		bytes calldata data,
		uint256 eta
	) external payable returns (bytes memory);
}
