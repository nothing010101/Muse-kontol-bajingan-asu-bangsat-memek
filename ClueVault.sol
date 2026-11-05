// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ClueVault — one vault per (puzzleId, solver)
/// @notice Stores the clue as bytes encrypted OFF-CHAIN with the solver's
/// address + Agent ID. Only the solver wallet may call revealClue().
/// @dev HONEST WARNING: everything on-chain is public. This contract gates
/// *access* through a msg.sender check — it does NOT make the bytes unreadable
/// to a node operator reading contract storage directly. Real secrecy comes
/// from the off-chain encryption keyed to the solver's identity, never from
/// this gate alone. Do not store a plaintext clue here.
contract ClueVault {
    bytes32 public immutable puzzleId;
    address public immutable solver;
    address public immutable factory;
    bytes private encryptedClue;

    event ClueStored(bytes32 indexed puzzleId, address indexed solver);

    constructor(bytes32 puzzleId_, address solver_, bytes memory encryptedClue_) {
        puzzleId = puzzleId_;
        solver = solver_;
        factory = msg.sender;
        encryptedClue = encryptedClue_;
        emit ClueStored(puzzleId_, solver_);
    }

    /// @notice Only the solver wallet can read the clue (via eth_call with
    /// from = solver). Anyone reading raw storage can still see the bytes.
    function revealClue() external view returns (bytes memory) {
        require(msg.sender == solver, "only the solver");
        return encryptedClue;
    }
}
