// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AgentGate.sol";

/// @title PuzzleRegistry — agent registration + clue unlock by burn
/// @notice Flow: (1) agent registers its .ai handle (ownership proven against
/// the HandleRegistry), (2) owner registers puzzle IDs, (3) agent calls
/// unlockClue(puzzleId) which burns exactly 100,000 burn tokens. No time
/// limit anywhere in this contract.
contract PuzzleRegistry is AgentGate {
    /// @notice 100,000 tokens, 18 decimals (TEST and the future real token).
    uint256 public constant BURN_AMOUNT = 100_000 * 10 ** 18;
    /// @notice Burn = transfer to the canonical dead address.
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    IERC20 public immutable burnToken;

    struct Puzzle {
        bytes32 contentHash;
        string source;
        bool exists;
    }

    mapping(bytes32 => Puzzle) public puzzles;
    /// @notice wallet => bare handle, e.g. "luna404" (no ".ai" suffix).
    mapping(address => string) public agentHandle;
    mapping(bytes32 => mapping(address => bool)) public clueUnlocked;

    event AgentRegistered(address indexed wallet, string handle);
    event PuzzleRegistered(bytes32 indexed puzzleId, bytes32 contentHash, string source);
    event ClueUnlocked(
        bytes32 indexed puzzleId,
        address indexed wallet,
        string handle,
        uint256 burned,
        uint256 timestamp
    );

    constructor(address registry_, address burnToken_) AgentGate(registry_) {
        burnToken = IERC20(burnToken_);
    }

    /// @notice Register the caller's .ai handle. Proves ownership on-chain:
    /// the registry must say this wallet owns the (bare) handle.
    function registerAgent(string calldata handle) external {
        require(address(handleRegistry) != address(0), "no registry set");
        require(isAgent(msg.sender), "not an .ai agent");
        string memory bare = stripAiSuffix(handle);
        require(bytes(bare).length > 0, "empty handle");
        require(handleRegistry.ownerOfHandle(bare) == msg.sender, "handle not owned by caller");
        agentHandle[msg.sender] = bare;
        emit AgentRegistered(msg.sender, bare);
    }

    /// @notice Owner registers a puzzle: its content hash + internet source.
    function registerPuzzle(
        bytes32 puzzleId,
        bytes32 contentHash,
        string calldata source
    ) external onlyOwner {
        puzzles[puzzleId] = Puzzle({contentHash: contentHash, source: source, exists: true});
        emit PuzzleRegistered(puzzleId, contentHash, source);
    }

    /// @notice Burn exactly 100,000 burn tokens to unlock one clue.
    /// The agent must approve(this, 100_000e18) on the token FIRST.
    /// One unlock per (puzzleId, agent) — replays are rejected.
    function unlockClue(bytes32 puzzleId) external {
        require(isAgent(msg.sender), "not an .ai agent");
        require(bytes(agentHandle[msg.sender]).length > 0, "register first");
        require(puzzles[puzzleId].exists, "unknown puzzle");
        require(!clueUnlocked[puzzleId][msg.sender], "clue already unlocked");
        require(
            burnToken.transferFrom(msg.sender, BURN_ADDRESS, BURN_AMOUNT),
            "burn failed"
        );
        clueUnlocked[puzzleId][msg.sender] = true;
        emit ClueUnlocked(
            puzzleId,
            msg.sender,
            agentHandle[msg.sender],
            BURN_AMOUNT,
            block.timestamp
        );
    }
}
