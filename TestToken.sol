// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title TestToken (TEST) — dummy burn token for Puzzle NFT testing
/// @notice 1,000,000,000 TEST minted once to the deployer. TEST ONLY.
/// The real project token will be created later by luna via flap.sh and is
/// NOT this contract. Swap the burn token address in PuzzleRegistry when the
/// real token exists.
contract TestToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("test", "TEST") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
