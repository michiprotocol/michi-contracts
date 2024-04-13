// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestAirdropClaim is Ownable {
    address public token;

    mapping(address => uint256) public amountClaimedByAddress;

    mapping(address => uint256) public allocationByAddress;

    mapping(address => bool) public airdropClaimed;

    error AirdropClaimedAlready(address account);

    error NothingToClaim();

    event Claimed(address account, uint256 quantity);

    constructor(address token_) {
        token = token_;
    }

    function claim() external {
        if (airdropClaimed[msg.sender]) revert AirdropClaimedAlready(msg.sender);
        uint256 allocation = allocationByAddress[msg.sender];
        if (allocation == 0) revert NothingToClaim();

        console.log("done");

        IERC20(token).transfer(msg.sender, allocation);
        amountClaimedByAddress[msg.sender] += allocation;
        airdropClaimed[msg.sender] = true;

        emit Claimed(msg.sender, allocation);
    }

    function setAllocation(address account, uint256 allocation) external onlyOwner {
        if (allocation == 0) revert NothingToClaim();
        allocationByAddress[account] = allocation;
    }
}
