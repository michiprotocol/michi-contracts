// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/MichiWalletNFT.sol";

contract WalletNFTTest is Test {
    MichiWalletNFT public michiWalletNFT;

    function setUp() public {
        michiWalletNFT = new MichiWalletNFT(0, 0);
    }

    function testCurrentIndexStarting() public {
        assertEq(michiWalletNFT.getCurrentIndex(), 0);
    }

    function testPriceStarting() public {
        assertEq(michiWalletNFT.mintPrice(), 0);
    }

    function testPriceChange() public {
        assertEq(michiWalletNFT.mintPrice(), 0);

        michiWalletNFT.setMintPrice(1 ether);
        assertEq(michiWalletNFT.mintPrice(), 1 ether);
    }

    function testSupplyChange() public {
        uint256 supplyBeforeMint = michiWalletNFT.totalSupply();
        assertEq(supplyBeforeMint, 0);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.prank(user1);
        michiWalletNFT.mint(user2);

        assertEq(michiWalletNFT.totalSupply(), supplyBeforeMint + 1);
    }

    function testRevertUnauthorizedPriceChange() public {
        address user = vm.addr(1);
        vm.prank(user);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        michiWalletNFT.setMintPrice(1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        uint256 idToMint = michiWalletNFT.getCurrentIndex();
        uint256 supplyBeforeMint = michiWalletNFT.totalSupply();
        vm.prank(user1);
        michiWalletNFT.mint(user2);

        assertEq(michiWalletNFT.getCurrentIndex(), idToMint + 1);
        assertEq(michiWalletNFT.totalSupply(), supplyBeforeMint + 1);
        assertEq(michiWalletNFT.ownerOf(idToMint), user2);
        assertEq(michiWalletNFT.balanceOf(user2), 1);
    }
}
