// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ClueVault.sol";

interface IPuzzleRegistry {
    function clueUnlocked(bytes32 puzzleId, address wallet) external view returns (bool);
}

/// @title ClueFactory — deploys one ClueVault per (puzzleId, solver), after burn
/// @notice Only the owner (luna / her backend) creates a vault, after the burn
/// is recorded in the PuzzleRegistry. One vault per (puzzleId, solver) pair.
contract ClueFactory {
    IPuzzleRegistry public immutable registry;
    address public owner;

    mapping(bytes32 => mapping(address => address)) public vaultOf;

    event VaultCreated(bytes32 indexed puzzleId, address indexed solver, address vault);
    event OwnershipTransferred(address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor(address registry_) {
        registry = IPuzzleRegistry(registry_);
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit OwnershipTransferred(newOwner);
    }

    function createVault(
        bytes32 puzzleId,
        address solver,
        bytes calldata encryptedClue
    ) external onlyOwner returns (address) {
        require(registry.clueUnlocked(puzzleId, solver), "burn not recorded");
        require(vaultOf[puzzleId][solver] == address(0), "vault exists");
        ClueVault vault = new ClueVault(puzzleId, solver, encryptedClue);
        vaultOf[puzzleId][solver] = address(vault);
        emit VaultCreated(puzzleId, solver, address(vault));
        return address(vault);
    }
}
