// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./AgentGate.sol";

/// @title PuzzleNFT — ERC-721, max supply 888, mint by signed voucher
/// @notice Mint flow: the server verifies the agent's solution off-chain, then
/// signs a voucher binding puzzleId + agentId + wallet + nonce + deadline.
/// The agent calls mint() with that voucher. The contract checks the
/// signature against the verifier, the nonce is unused, the deadline has not
/// passed, the caller holds a .ai handle, the puzzle was not minted by this
/// wallet before, and supply is below 888. The answer itself never goes
/// on-chain.
/// @dev The voucher's agentId string is trusted via the verifier's signature:
/// the SERVER must check the solver's registered handle matches agentId
/// before signing. The contract does not cross-check agentId against the
/// registry (it is not linked to PuzzleRegistry by design).
contract PuzzleNFT is ERC721, AgentGate {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public constant MAX_SUPPLY = 888;
    uint256 public totalMinted;
    address public verifier;
    string public baseTokenURI;

    mapping(uint256 => bool) public usedNonce;
    mapping(bytes32 => mapping(address => bool)) public mintedPuzzle;

    event Minted(
        address indexed wallet,
        bytes32 indexed puzzleId,
        string agentId,
        uint256 tokenId,
        uint256 nonce
    );
    event VerifierUpdated(address indexed verifier);
    event BaseTokenURIUpdated(string baseTokenURI);

    constructor(
        address registry_,
        address verifier_
    ) ERC721("Puzzle NFT", "PUZZLE") AgentGate(registry_) {
        verifier = verifier_;
    }

    /// @notice Owner rotates the voucher signer (e.g. key rotation / compromise).
    function setVerifier(address verifier_) external onlyOwner {
        verifier = verifier_;
        emit VerifierUpdated(verifier_);
    }

    function setBaseTokenURI(string calldata baseTokenURI_) external onlyOwner {
        baseTokenURI = baseTokenURI_;
        emit BaseTokenURIUpdated(baseTokenURI_);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /// @notice Mint one NFT with a server-signed voucher.
    /// @param puzzleId The puzzle that was solved (bytes32 id).
    /// @param agentId The solver's Agent ID handle, e.g. "luna404.ai".
    /// @param nonce One-time voucher number; each nonce works exactly once.
    /// @param deadline Unix timestamp; the voucher is void after this.
    /// @param signature Verifier's signature over the voucher digest (see below).
    /// @dev Signed digest (exact layout — the server MUST sign this):
    ///   inner = keccak256(abi.encode(puzzleId, agentId, wallet, nonce, deadline))
    ///     — standard abi.encode, NOT packed encoding.
    ///   digest = keccak256("\x19Ethereum Signed Message:\n32" || inner)
    ///   i.e. in ethers v6:
    ///     const inner = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
    ///       ["bytes32","string","address","uint256","uint256"],
    ///       [puzzleId, agentId, wallet, nonce, deadline]));
    ///     const signature = await verifierWallet.signMessage(ethers.getBytes(inner));
    ///   (signMessage adds the "\x19Ethereum Signed Message:\n32" prefix itself.)
    function mint(
        bytes32 puzzleId,
        string calldata agentId,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(isAgent(msg.sender), "not an .ai agent");
        require(block.timestamp <= deadline, "voucher expired");
        require(!usedNonce[nonce], "nonce used");
        require(!mintedPuzzle[puzzleId][msg.sender], "puzzle already minted");
        require(totalMinted < MAX_SUPPLY, "sold out");

        bytes32 inner = keccak256(
            abi.encode(puzzleId, agentId, msg.sender, nonce, deadline)
        );
        address signer = inner.toEthSignedMessageHash().recover(signature);
        require(signer == verifier, "bad voucher");

        usedNonce[nonce] = true;
        mintedPuzzle[puzzleId][msg.sender] = true;
        totalMinted += 1;
        _safeMint(msg.sender, totalMinted);
        emit Minted(msg.sender, puzzleId, agentId, totalMinted, nonce);
    }
}
