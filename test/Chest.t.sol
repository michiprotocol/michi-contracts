// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/MichiChest.sol";

contract ChestTest is Test {
    MichiChest public michiChest;

    function setUp() public {
        michiChest = new MichiChest(0, 0);
    }

    function testCurrentIndexStarting() public {
        assertEq(michiChest.getCurrentIndex(), 0);
    }

    function testPriceStarting() public {
        assertEq(michiChest.mintPrice(), 0);
    }

    function testPriceChange() public {
        assertEq(michiChest.mintPrice(), 0);

        michiChest.setMintPrice(1 ether);
        assertEq(michiChest.mintPrice(), 1 ether);
    }

    function testSupplyChange() public {
        uint256 supplyBeforeMint = michiChest.totalSupply();
        assertEq(supplyBeforeMint, 0);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.prank(user1);
        michiChest.mint(user2);

        assertEq(michiChest.totalSupply(), supplyBeforeMint + 1);
    }

    function testRevertUnauthorizedPriceChange() public {
        address user = vm.addr(1);
        vm.prank(user);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        michiChest.setMintPrice(1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        uint256 idToMint = michiChest.getCurrentIndex();
        uint256 supplyBeforeMint = michiChest.totalSupply();
        vm.prank(user1);
        michiChest.mint(user2);

        assertEq(michiChest.getCurrentIndex(), idToMint + 1);
        assertEq(michiChest.totalSupply(), supplyBeforeMint + 1);
        assertEq(michiChest.ownerOf(idToMint), user2);
        assertEq(michiChest.balanceOf(user2), 1);
    }
}
