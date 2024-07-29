// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestWalletConnect is Ownable {
    address public token;

    address public storedAddress;

    uint256 public allocation;

    uint256 public value;

    mapping(address => uint256) public amountClaimedByAddress;

    event Claimed(address account, uint256 quantity);

    event Deposit(address account, uint256 quantity);

    event NewValueSet(uint256 newValue);

    event NewAddressStored(address newAddress);

    constructor(address token_, uint256 allocation_) {
        token = token_;
        allocation = allocation_;
    }

    function claim() external {
        amountClaimedByAddress[msg.sender] += allocation;
        IERC20(token).transfer(msg.sender, allocation);

        emit Claimed(msg.sender, allocation);
    }

    function depositTokens(uint256 quantity) external {
        IERC20(token).transferFrom(msg.sender, address(this), quantity);

        emit Deposit(msg.sender, quantity);
    }

    function setValue(uint256 newValue) external {
        value = newValue;

        emit NewValueSet(newValue);
    }

    function storeAddress(address newAddress) external {
        storedAddress = newAddress;

        emit NewAddressStored(newAddress);
    }

    function setAllocation(uint256 newAllocation) external onlyOwner {
        allocation = newAllocation;
    }
}
