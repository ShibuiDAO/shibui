// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Base contracts
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {ITimelock} from "./interfaces/ITimelock.sol";

/// @title Timelock
/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/governance/Timelock.sol)
/// @author Modified from Compound (https://github.com/compound-finance/compound-protocol/blob/master/contracts/Timelock.sol)
contract Timelock is Ownable, ITimelock {
	///////////////////////////////////////////////////
	///                  CONSTANTS                  ///
	///////////////////////////////////////////////////

	uint256 public constant GRACE_PERIOD = 14 days;
	uint256 public constant MINIMUM_DELAY = 1 days;
	uint256 public constant MAXIMUM_DELAY = 30 days;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                            TIMELOCK CONFIGURATION                                            ///
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	uint256 public delay;

	/////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                      TRANSACTION STORAGE                                      ///
	/////////////////////////////////////////////////////////////////////////////////////////////////////

	mapping(bytes32 => bool) public queuedTransactions;

	//////////////////////////////////////////////////////////////////////////////////////
	///                                RECEIVE HANDLING                                ///
	//////////////////////////////////////////////////////////////////////////////////////

	// solhint-disable-next-line no-empty-blocks
	receive() external payable {}

	////////////////////////////////////////////////////////////////////////////
	///                            INITIALIZATION                            ///
	////////////////////////////////////////////////////////////////////////////

	constructor(uint256 _delay) {
		require(_delay >= MINIMUM_DELAY, "DELAY_TOO_SHORT");
		require(_delay <= MAXIMUM_DELAY, "DELAY_TOO_LONG");

		delay = _delay;
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                TIMELOCK ADMIN FUNCTIONS                                                ///
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function setDelay(uint256 _delay) public override onlyOwner {
		require(_delay >= MINIMUM_DELAY, "DELAY_TOO_SHORT");
		require(_delay <= MAXIMUM_DELAY, "DELAY_TOO_LONG");
		delay = _delay;

		emit NewDelay(delay);
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                          TRANSACTION FUNCTIONS                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////

	function queueTransaction(
		address target,
		uint256 value,
		string calldata signature,
		bytes calldata data,
		uint256 eta
	) public override onlyOwner returns (bytes32) {
		require(eta >= getBlockTimestamp() + delay, "TRANSACTION_LOW_DELAY");

		bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
		queuedTransactions[txHash] = true;

		emit QueueTransaction(txHash, target, value, signature, data, eta);
		return txHash;
	}

	function cancelTransaction(
		address target,
		uint256 value,
		string calldata signature,
		bytes calldata data,
		uint256 eta
	) public override onlyOwner {
		bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
		queuedTransactions[txHash] = false;

		emit CancelTransaction(txHash, target, value, signature, data, eta);
	}

	function executeTransaction(
		address target,
		uint256 value,
		string calldata signature,
		bytes calldata data,
		uint256 eta
	) public payable override onlyOwner returns (bytes memory) {
		bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
		require(queuedTransactions[txHash], "TRANSACTION_NOT_QUEUED");
		require(getBlockTimestamp() >= eta, "TRANSACTION_TOO_YOUNG");
		require(getBlockTimestamp() <= eta + GRACE_PERIOD, "TRANSACTION_STALE");

		queuedTransactions[txHash] = false;

		bytes memory callData;

		if (bytes(signature).length == 0) {
			callData = data;
		} else {
			callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
		}

		// solhint-disable-next-line avoid-low-level-calls
		(bool success, bytes memory returnData) = target.call{value: value}(callData);
		require(success, "TRANSACTION_REVERT");

		emit ExecuteTransaction(txHash, target, value, signature, data, eta);

		return returnData;
	}

	///////////////////////////////////////////////////////////////////////////////////////////
	///                                  UTILITY FUNCTIONS                                  ///
	///////////////////////////////////////////////////////////////////////////////////////////

	function getBlockTimestamp() internal view returns (uint256) {
		// solhint-disable-next-line not-rely-on-time
		return block.timestamp;
	}
}
