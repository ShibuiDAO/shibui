// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/// @title 🌊 Shibui 🌊
contract Shibui is ERC20("Shibui", unicode"🌊"), ERC20Burnable, ERC20Snapshot, ERC20Permit("Shibui") {
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override(ERC20, ERC20Snapshot) {
		ERC20Snapshot._beforeTokenTransfer(from, to, amount);
	}
}
