// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/MichiBackpack.sol";

contract BackpackTest2 is Test {
    MichiBackpack public michiBackpack;

    function setUp() public {
        michiBackpack = new MichiBackpack(0, 0.5 ether);
    }

    function testPrice() public {
        assertEq(michiBackpack.mintPrice(), 0.5 ether);
    }

    function testPriceChange() public {
        michiBackpack.setMintPrice(1 ether);
        assertEq(michiBackpack.mintPrice(), 1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        uint256 idToMint = michiBackpack.getCurrentIndex();
        uint256 supplyBeforeMint = michiBackpack.totalSupply();
        vm.prank(user1);
        michiBackpack.mint{value: 0.5 ether}(user2);

        assertEq(michiBackpack.getCurrentIndex(), idToMint + 1);
        assertEq(michiBackpack.totalSupply(), supplyBeforeMint + 1);
        assertEq(michiBackpack.ownerOf(idToMint), user2);
        assertEq(michiBackpack.balanceOf(user2), 1);
    }

    function testRevertWhenIncorrectValueSent() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MichiBackpack.InvalidPayableAmount.selector, 1 ether));
        michiBackpack.mint{value: 1 ether}(user2);
    }

    function testWithdrawBalance() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        michiBackpack.mint{value: 0.5 ether}(user2);

        uint256 backpackBalanceBeforeWithdraw = address(michiBackpack).balance;
        uint256 balanceBeforeWithdraw = msg.sender.balance;
        michiBackpack.withdraw(msg.sender);
        assertEq(address(michiBackpack).balance, 0);
        assertApproxEqAbs(msg.sender.balance, backpackBalanceBeforeWithdraw + balanceBeforeWithdraw, 0.01 ether);
    }

    function testRevertWhenUnauthorizedWithdrawal() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        michiBackpack.mint{value: 0.5 ether}(user2);

        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        michiBackpack.withdraw(user1);
    }
}
