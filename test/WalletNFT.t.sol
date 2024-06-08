// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/PichiWalletNFT.sol";

contract WalletNFTTest is Test {
    PichiWalletNFT public pichiWalletNFT;

    function setUp() public {
        pichiWalletNFT = new PichiWalletNFT(0, 0);
    }

    function testCurrentIndexStarting() public {
        assertEq(pichiWalletNFT.getCurrentIndex(), 0);
    }

    function testPriceStarting() public {
        assertEq(pichiWalletNFT.mintPrice(), 0);
    }

    function testPriceChange() public {
        assertEq(pichiWalletNFT.mintPrice(), 0);

        pichiWalletNFT.setMintPrice(1 ether);
        assertEq(pichiWalletNFT.mintPrice(), 1 ether);
    }

    function testSupplyChange() public {
        uint256 supplyBeforeMint = pichiWalletNFT.totalSupply();
        assertEq(supplyBeforeMint, 0);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.prank(user1);
        pichiWalletNFT.mint(user2);

        assertEq(pichiWalletNFT.totalSupply(), supplyBeforeMint + 1);
    }

    function testRevertUnauthorizedPriceChange() public {
        address user = vm.addr(1);
        vm.prank(user);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pichiWalletNFT.setMintPrice(1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        uint256 idToMint = pichiWalletNFT.getCurrentIndex();
        uint256 supplyBeforeMint = pichiWalletNFT.totalSupply();
        vm.prank(user1);
        pichiWalletNFT.mint(user2);

        assertEq(pichiWalletNFT.getCurrentIndex(), idToMint + 1);
        assertEq(pichiWalletNFT.totalSupply(), supplyBeforeMint + 1);
        assertEq(pichiWalletNFT.ownerOf(idToMint), user2);
        assertEq(pichiWalletNFT.balanceOf(user2), 1);
    }
}
