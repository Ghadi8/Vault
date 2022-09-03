// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice libraries

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Escapable
 * @author Ghadi Mhawej
 **/

contract Escapable is Ownable, ReentrancyGuard {
    address public escapeHatchCaller;
    address payable public escapeHatchDestination;

    /// @notice EscapeHatch event definition
    event EscapeHatchCalled(uint256 amount);

    /// @dev The addresses preassigned to the `escapeHatchCaller` role or the owner are the only addresses that can call a function with this modifier
    modifier onlyEscapeHatchCallerOrOwner() {
        require(
            _msgSender() == owner() || _msgSender() == escapeHatchCaller,
            "Escapable: caller is not the owner or escapeHatchCaller"
        );
        _;
    }

    /// @notice The Constructor assigns the `escapeHatchDestination` and the `escapeHatchCaller`
    /// @param _escapeHatchDestination The address of a safe location to send the ether held in this contract to
    /// @param _escapeHatchCaller The address of a trusted account or contract to send the ether in this contract
    constructor(address _escapeHatchCaller, address _escapeHatchDestination) {
        escapeHatchCaller = _escapeHatchCaller;
        escapeHatchDestination = payable(_escapeHatchDestination);
    }

    /// @notice Changes the address assigned to call `escapeHatch()`
    /// @param _newEscapeHatchCaller New address to be assigned to escapeHatchCaller
    function changeEscapeCaller(address _newEscapeHatchCaller)
        external
        onlyEscapeHatchCallerOrOwner
    {
        escapeHatchCaller = _newEscapeHatchCaller;
    }

    /// @notice Sends all of the eth contained in the contract to the escapeHatchDestination
    /// @notice should only be called as last resort
    function escapeHatch() external onlyEscapeHatchCallerOrOwner nonReentrant {
        uint256 total = address(this).balance;

        escapeHatchDestination.transfer(total);
        emit EscapeHatchCalled(total);
    }
}
