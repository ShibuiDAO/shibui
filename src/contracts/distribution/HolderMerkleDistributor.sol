// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Interfaces
import {IHolderMerkleDistributor} from "./interfaces/IHolderMerkleDistributor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Structures, libraries, utilities
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract HolderMerkleDistributor is IHolderMerkleDistributor{
	address public immutable override token;
	uint256 public immutable override perClaim;
	bytes32 public immutable override root;

	mapping(address => bool) private claims;

	constructor(
		address token_,
		uint256 perClaim_,
		bytes32 root_
	) {
		token = token_;
		perClaim = perClaim_;
		root = root_;
	}

	function hasClaimed(address account_) public view override returns (bool claimed) {
		return claims[account_];
	}

	function claim(
		uint256 index,
		address account,
		uint256 amount,
		bytes32[] calldata merkleProof
	) external override {
		require(!hasClaimed(account), "CLAIMED");

		bytes32 node = keccak256(abi.encodePacked(index, account, amount));
		require(MerkleProof.verify(merkleProof, root, node), "PROOF_FAIL");

		claims[account] = true;
		require(IERC20(token).transfer(account, amount * perClaim), "TRANSFER_INVALID");

        emit Claimed(index, account, amount);
	}
}
