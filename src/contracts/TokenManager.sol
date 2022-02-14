// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/TokenManager.sol)
/// @author Modified from Rollcall by Tally (https://github.com/withtally/rollcall/blob/main/src/Treasury.sol)
/// @author Modified from Alchemist (https://github.com/alchemistcoin/alchemist/blob/main/contracts/TokenManager.sol)
contract TokenManager is ERC721Holder, ERC1155Holder, Ownable {
	error UNDERLYING_CONTRACT_REVERTED();

	// solhint-disable-next-line no-empty-blocks
	receive() external payable {}

	/*///////////////////////////////////////////////////////////////
                      ARBITRARY EXECUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function execute(
		address target,
		uint256 value,
		bytes calldata data
	) external onlyOwner {
		// solhint-disable-next-line avoid-low-level-calls
		(bool success, ) = target.call{value: value}(data);
		if (!success) {
			revert UNDERLYING_CONTRACT_REVERTED();
		}
	}

	/*///////////////////////////////////////////////////////////////
                         ERC20 INTERACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function transferERC20(
		address token,
		address to,
		uint256 value
	) external onlyOwner {
		SafeTransferLib.safeTransfer(ERC20(token), to, value);
	}

	function transferFromERC20(
		address token,
		address from,
		address to,
		uint256 value
	) external onlyOwner {
		SafeTransferLib.safeTransferFrom(ERC20(token), from, to, value);
	}

	function approveERC20(
		address token,
		address to,
		uint256 value
	) external onlyOwner {
		SafeTransferLib.safeApprove(ERC20(token), to, value);
	}

	/*///////////////////////////////////////////////////////////////
                         ERC721 INTERACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function approveERC721(
		address token,
		address to,
		uint256 tokenId
	) external onlyOwner {
		IERC721(token).approve(to, tokenId);
	}

	function setApprovalForAllERC721(
		address token,
		address to,
		bool active
	) external onlyOwner {
		IERC721(token).setApprovalForAll(to, active);
	}

	function transferFromERC721(
		address token,
		address from,
		address to,
		uint256 tokenId
	) external onlyOwner {
		IERC721(token).transferFrom(from, to, tokenId);
	}

	function safeTransferFromERC721(
		address token,
		address from,
		address to,
		uint256 tokenId
	) external onlyOwner {
		IERC721(token).safeTransferFrom(from, to, tokenId);
	}

	function safeTransferFromERC721(
		address token,
		address from,
		address to,
		uint256 tokenId,
		bytes calldata data
	) external onlyOwner {
		IERC721(token).safeTransferFrom(from, to, tokenId, data);
	}

	/*///////////////////////////////////////////////////////////////
                         ERC1155 INTERACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function setApprovalForAllERC1155(
		address token,
		address to,
		bool active
	) external onlyOwner {
		IERC1155(token).setApprovalForAll(to, active);
	}

	function safeTransferFromERC1155(
		address token,
		address from,
		address to,
		uint256 id,
		uint256 amount,
		bytes calldata data
	) external onlyOwner {
		IERC1155(token).safeTransferFrom(from, to, id, amount, data);
	}

	function safeBatchTransferFromERC1155(
		address token,
		address from,
		address to,
		uint256[] calldata ids,
		uint256[] calldata amounts,
		bytes calldata data
	) external onlyOwner {
		IERC1155(token).safeBatchTransferFrom(from, to, ids, amounts, data);
	}

	/*///////////////////////////////////////////////////////////////
                          ETH INTERACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function transferETH(address to, uint256 value) external onlyOwner {
		SafeTransferLib.safeTransferETH(to, value);
	}
}
