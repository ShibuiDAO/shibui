// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

interface IHolderMerkleDistributor {
	event Claimed(uint256 indexed index, address indexed account, uint256 indexed amount);

	function token() external view returns (address);

	function perClaim() external view returns (uint256);

	function root() external view returns (bytes32);

	function hasClaimed(address account_) external view returns (bool claimed);

    function claim(
		uint256 index,
		address account,
		uint256 amount,
		bytes32[] calldata merkleProof
	)
}
