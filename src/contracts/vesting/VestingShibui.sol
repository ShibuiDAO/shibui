// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Base contracts
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IShibui} from "../shibui/interfaces/IShibui.sol";

// Structures, libraries, utilities
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VestingShibui is Context, Ownable {
	using SafeERC20 for IShibui;

	IShibui public immutable shibui;

	address public beneficiary;
	uint256 public endTimestamp;

	constructor(address _shibui, address _beneficiary) {
		require(_shibui != address(0), "SHIBUI_ZERO_ADDRESS");
		shibui = IShibui(_shibui);

		require(_beneficiary != address(0), "BENEFICIARY_ZERO_ADDRESS");
		beneficiary = _beneficiary;
	}

	function vest(uint256 _endTimestamp) external onlyOwner {
		require(endTimestamp == 0, "VESTING_STARTED");
		// solhint-disable-next-line not-rely-on-time
		require(_endTimestamp > block.timestamp, "VESTING_BEFORE_NOW");

		endTimestamp = _endTimestamp;
		shibui.delegate(beneficiary);
	}

	function changeBeneficiary(address _newBeneficiary) external {
		require(_msgSender() == beneficiary || _msgSender() == owner(), "CALLER_NOT_PERMITTED");
		require(_newBeneficiary != address(0), "BENEFICIARY_ZERO_ADDRESS");

		beneficiary = _newBeneficiary;
		shibui.delegate(beneficiary);
	}

	function release() public {
		require(endTimestamp != 0, "VESTING_IDLE");
		// solhint-disable-next-line not-rely-on-time
		require(block.timestamp >= endTimestamp, "TIME_BEFORE_RELEASE");

		uint256 amount = shibui.balanceOf(address(this));
		require(amount > 0, "BALANCE_EMPTY");

		shibui.safeTransfer(beneficiary, amount);
		_transferOwnership(address(0));
	}
}
