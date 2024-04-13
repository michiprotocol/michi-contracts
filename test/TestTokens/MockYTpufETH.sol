// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockYTpufETH is ERC20 {
    constructor() ERC20("Mock YT-pufETH-26JUN24", "Mock YT-pufETH-26JUN24") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
