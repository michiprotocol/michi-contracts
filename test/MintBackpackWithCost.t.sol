// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/MichiChest.sol";

contract ChestTest2 is Test {
    MichiChest public michiChest;

    function setUp() public {
        michiChest = new MichiChest(0, 0.5 ether);
    }

    function testPrice() public {
        assertEq(michiChest.mintPrice(), 0.5 ether);
    }

    function testPriceChange() public {
        michiChest.setMintPrice(1 ether);
        assertEq(michiChest.mintPrice(), 1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        uint256 idToMint = michiChest.getCurrentIndex();
        uint256 supplyBeforeMint = michiChest.totalSupply();
        vm.prank(user1);
        michiChest.mint{value: 0.5 ether}(user2);

        assertEq(michiChest.getCurrentIndex(), idToMint + 1);
        assertEq(michiChest.totalSupply(), supplyBeforeMint + 1);
        assertEq(michiChest.ownerOf(idToMint), user2);
        assertEq(michiChest.balanceOf(user2), 1);
    }

    function testRevertWhenIncorrectValueSent() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MichiChest.InvalidPayableAmount.selector, 1 ether));
        michiChest.mint{value: 1 ether}(user2);
    }

    function testWithdrawBalance() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        michiChest.mint{value: 0.5 ether}(user2);

        uint256 chestBalanceBeforeWithdraw = address(michiChest).balance;
        uint256 balanceBeforeWithdraw = msg.sender.balance;
        michiChest.withdraw(msg.sender);
        assertEq(address(michiChest).balance, 0);
        assertApproxEqAbs(msg.sender.balance, chestBalanceBeforeWithdraw + balanceBeforeWithdraw, 0.01 ether);
    }

    function testRevertWhenUnauthorizedWithdrawal() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        michiChest.mint{value: 0.5 ether}(user2);

        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        michiChest.withdraw(user1);
    }
}
