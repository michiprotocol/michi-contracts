// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/MichiBackpack.sol";

contract BackpackTest is Test {
    MichiBackpack public michiBackpack;

    function setUp() public {
        michiBackpack = new MichiBackpack(0, 0);
    }

    function testCurrentIndexStarting() public {
        assertEq(michiBackpack.getCurrentIndex(), 0);
    }

    function testPriceStarting() public {
        assertEq(michiBackpack.mintPrice(), 0);
    }

    function testPriceChange() public {
        assertEq(michiBackpack.mintPrice(), 0);

        michiBackpack.setMintPrice(1 ether);
        assertEq(michiBackpack.mintPrice(), 1 ether);
    }

    function testSupplyChange() public {
        uint256 supplyBeforeMint = michiBackpack.totalSupply();
        assertEq(supplyBeforeMint, 0);

        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.prank(user1);
        michiBackpack.mint(user2);

        assertEq(michiBackpack.totalSupply(), supplyBeforeMint + 1);
    }

    function testRevertUnauthorizedPriceChange() public {
        address user = vm.addr(1);
        vm.prank(user);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        michiBackpack.setMintPrice(1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        uint256 idToMint = michiBackpack.getCurrentIndex();
        uint256 supplyBeforeMint = michiBackpack.totalSupply();
        vm.prank(user1);
        michiBackpack.mint(user2);

        assertEq(michiBackpack.getCurrentIndex(), idToMint + 1);
        assertEq(michiBackpack.totalSupply(), supplyBeforeMint + 1);
        assertEq(michiBackpack.ownerOf(idToMint), user2);
        assertEq(michiBackpack.balanceOf(user2), 1);
    }
}
