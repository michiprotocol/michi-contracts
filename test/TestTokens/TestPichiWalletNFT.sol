// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestPichiWalletNFT is ERC721, Ownable {
    /// @notice tracks the next index to be minted
    uint256 public currentIndex;

    /// @notice tracks the total supply minted
    uint256 public totalSupply;

    event Mint(address indexed minter, uint256 nftId);

    event Withdrawal(address indexed withdrawer, uint256 amount);

    error WithdrawalFailed();

    constructor(uint256 startingIndex_) ERC721("Test Pichi Wallet NFT", "PICHI") {
        currentIndex = startingIndex_;
    }

    function getCurrentIndex() public view returns (uint256) {
        return currentIndex;
    }

    function mint(address to) external {
        _safeMint(to, currentIndex);

        emit Mint(to, currentIndex);
        currentIndex++;
        totalSupply++;
    }

    receive() external payable {}
}
