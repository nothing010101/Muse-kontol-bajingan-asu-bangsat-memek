// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IHandleRegistry {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOfHandle(string calldata handle) external view returns (address);
    function handleOf(address owner) external view returns (string memory);
}

/// @title AgentGate — the .ai handle gate, shared by PuzzleRegistry and PuzzleNFT
/// @notice A wallet counts as an agent iff it holds a SPACE ID Agent ID
/// (Binance Agent-ID soulbound token) in the HandleRegistry, OR the owner has
/// explicitly allowlisted it (test fallback only).
/// @dev Registry VERIFIED live 2026-11-06 (block 131876975, BSC):
///   0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F — "SPACE ID Agent ID" (AI),
///   exact Sourcify match, contract HandleRegistry.
///   luna wallet 0x9707C99D8247fBBB5E806a389160372602578009:
///   balanceOf = 1, handleOf = "luna404",
///   ownerOfHandle("luna404") = wallet, isValidHandle("luna404") = true.
///   IMPORTANT: the registry stores BARE handles ("luna404"), NOT "luna404.ai"
///   (isValidHandle("luna404.ai") == false). Always strip a trailing ".ai" first.
abstract contract AgentGate is Ownable {
    IHandleRegistry public handleRegistry;
    mapping(address => bool) public allowlisted;

    event HandleRegistryUpdated(address indexed registry);
    event AllowlistedUpdated(address indexed wallet, bool allowed);

    constructor(address registry_) Ownable(msg.sender) {
        handleRegistry = IHandleRegistry(registry_);
    }

    function setHandleRegistry(address registry_) external onlyOwner {
        handleRegistry = IHandleRegistry(registry_);
        emit HandleRegistryUpdated(registry_);
    }

    /// @notice Owner allowlist — test fallback for wallets without an Agent ID.
    /// In production this stays empty; the registry check is the real gate.
    function setAllowlisted(address wallet, bool allowed) external onlyOwner {
        allowlisted[wallet] = allowed;
        emit AllowlistedUpdated(wallet, allowed);
    }

    /// @notice Single isolated .ai check. Primary: live HandleRegistry balance.
    /// Fallback: owner allowlist.
    function isAgent(address wallet) public view returns (bool) {
        if (allowlisted[wallet]) return true;
        if (address(handleRegistry) == address(0)) return false;
        return handleRegistry.balanceOf(wallet) > 0;
    }

    /// @notice Strip one trailing ".ai" so "luna404.ai" -> "luna404".
    function stripAiSuffix(string memory handle) public pure returns (string memory) {
        bytes memory b = bytes(handle);
        if (
            b.length > 3 &&
            b[b.length - 3] == bytes1(".") &&
            b[b.length - 2] == bytes1("a") &&
            b[b.length - 1] == bytes1("i")
        ) {
            bytes memory out = new bytes(b.length - 3);
            for (uint256 i = 0; i < b.length - 3; i++) out[i] = b[i];
            return string(out);
        }
        return handle;
    }
}
