// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPichiWalletNFT {
    function getCurrentIndex() external view returns (uint256);

    function getMintPrice() external view returns (uint256);

    function mint(address recipient) external payable;

    function dummyMint() external;
}
