// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

// Interfaces
import {ICrossDomainMessenger} from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

/// @title L2 -> L1 Executor
/// @author ShibuiDAO (https://github.com/ShibuiDAO/shibui/blob/main/src/contracts/governance/L1Executor.sol)
/// @author Modified from Rollcall by Tally (https://github.com/withtally/rollcall/blob/main/src/Executor.sol)
contract L1Executor {
	///////////////////////////////////////////////////
	///                  CONSTANTS                  ///
	///////////////////////////////////////////////////

    /// @dev Interface representing the L2->L1 CDM.
	ICrossDomainMessenger private immutable cdm;

    /// @notice Address of the L2 DAO executor (Governor/Timelock).
	address public immutable l2DAO;

	////////////////////////////////////////////////////////////////////////////
	///                            INITIALIZATION                            ///
	////////////////////////////////////////////////////////////////////////////

    /// @param _cdm Address of the L2->L1 CDM.
    /// @param _l2DAO Address of the L2 DAO executor (Governor/Timelock).
	constructor(address _cdm, address _l2DAO) {
		cdm = ICrossDomainMessenger(_cdm);
		l2DAO = _l2DAO;
	}

	///////////////////////////////////////////////////
	///                  MODIFIERS                  ///
	///////////////////////////////////////////////////

	/// @notice Throws if called by any account other than the L2 dao contract.
	modifier onlyL2DAO() {
		require(msg.sender == address(cdm) && cdm.xDomainMessageSender() == l2DAO, "EXECUTOR_NOT_DAO");
		_;
	}

	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///                                                          ARBITRARY EXECUTION FUNCTIONS                                                          ///
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	/// @notice Proxies an execution payload bridged from Layer 2.
    /// @dev Verfies the execution payload source is the configured Layer 2 Governance.
	function execute(address target, bytes calldata data) public onlyL2DAO {
		// solhint-disable-next-line avoid-low-level-calls
		(bool success, ) = target.call(data);
		require(success, "UNDERLYING_CONTRACT_REVERTED");
	}
}
