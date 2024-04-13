// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockYT is ERC20 {
    constructor() ERC20("Mock YT-eETH-27JUN24", "Mock YT-eETH-27JUN24") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
