// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PichiWalletNFT is ERC721, Ownable {
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
        currentIndex = startingIndex_;
        mintPrice = mintPrice_;
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

    function setMintPrice(uint256 newMintPrice_) external onlyOwner {
        mintPrice = newMintPrice_;
    }

    function withdraw(address to) external onlyOwner {
        uint256 withdrawAmount = address(this).balance;
        (bool success,) = to.call{value: withdrawAmount}("");

        if (!success) revert WithdrawalFailed();

        emit Withdrawal(msg.sender, withdrawAmount);
    }

    receive() external payable {}
}
