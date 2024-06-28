// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PichiWalletNFT is ERC721, AccessControl {
    bytes32 public constant INCREMENT_ROLE = keccak256("INCREMENT_ROLE");

    /// @notice tracks the next index to be minted
    uint256 public currentIndex;

    /// @notice tracks the total supply minted
    uint256 public totalSupply;

    /// @notice mint price in ETH
    uint256 public mintPrice;

    event Mint(address indexed minter, uint256 nftId);

    event Withdrawal(address indexed withdrawer, uint256 amount);

    error InvalidPayableAmount(uint256 amount);

    error WithdrawalFailed();

    constructor(uint256 startingIndex_, uint256 mintPrice_) ERC721("Pichi Wallet NFT", "PICHI") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        currentIndex = startingIndex_;
        mintPrice = mintPrice_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getCurrentIndex() public view returns (uint256) {
        return currentIndex;
    }

    function getMintPrice() external view returns (uint256) {
        return mintPrice;
    }

    function mint(address to) external payable {
        if (msg.value != mintPrice) revert InvalidPayableAmount(msg.value);
        _safeMint(to, currentIndex);

        emit Mint(to, currentIndex);
        currentIndex++;
        totalSupply++;
    }

    // used when TBA for next tokenId has already been taken
    // increments currentIndex and totalSupply without actually minting
    function dummyMint() external onlyRole(INCREMENT_ROLE) {
        currentIndex++;
        totalSupply++;
    }

    function setMintPrice(uint256 newMintPrice_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintPrice = newMintPrice_;
    }

    function withdraw(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 withdrawAmount = address(this).balance;
        (bool success,) = to.call{value: withdrawAmount}("");

        if (!success) revert WithdrawalFailed();

        emit Withdrawal(msg.sender, withdrawAmount);
    }

    function grantIncrementRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(INCREMENT_ROLE, user);
    }

    function revokeIncrementRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(INCREMENT_ROLE, user);
    }

    receive() external payable {}
}
