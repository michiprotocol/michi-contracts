// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MichiWalletReceiptNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice tracks the total supply minted
    uint256 public totalSupply;

    error UnauthorizedMinter(address user);

    event Mint(address indexed minter, uint256 nftId);

    constructor() ERC721("Michi Wallet Receipt NFT", "MICHI RECEIPT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        totalSupply++;
        _safeMint(to, tokenId);

        emit Mint(to, tokenId);
    }

    function grantMinterRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, user);
    }

    function revokeMinterRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, user);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
