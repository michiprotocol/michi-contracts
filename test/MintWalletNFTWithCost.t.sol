// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/PichiWalletNFT.sol";

contract WalletNFTTest2 is Test {
    PichiWalletNFT public pichiWalletNFT;

    function setUp() public {
        pichiWalletNFT = new PichiWalletNFT(0, 0.5 ether);
    }

    function testPrice() public {
        assertEq(pichiWalletNFT.mintPrice(), 0.5 ether);
    }

    function testPriceChange() public {
        pichiWalletNFT.setMintPrice(1 ether);
        assertEq(pichiWalletNFT.mintPrice(), 1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        uint256 idToMint = pichiWalletNFT.getCurrentIndex();
        uint256 supplyBeforeMint = pichiWalletNFT.totalSupply();
        vm.prank(user1);
        pichiWalletNFT.mint{value: 0.5 ether}(user2);

        assertEq(pichiWalletNFT.getCurrentIndex(), idToMint + 1);
        assertEq(pichiWalletNFT.totalSupply(), supplyBeforeMint + 1);
        assertEq(pichiWalletNFT.ownerOf(idToMint), user2);
        assertEq(pichiWalletNFT.balanceOf(user2), 1);
    }

    function testRevertWhenIncorrectValueSent() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(PichiWalletNFT.InvalidPayableAmount.selector, 1 ether));
        pichiWalletNFT.mint{value: 1 ether}(user2);
    }

    function testWithdrawBalance() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        pichiWalletNFT.mint{value: 0.5 ether}(user2);

        uint256 walletBalanceBeforeWtihdraw = address(pichiWalletNFT).balance;
        uint256 balanceBeforeWithdraw = msg.sender.balance;
        pichiWalletNFT.withdraw(msg.sender);
        assertEq(address(pichiWalletNFT).balance, 0);
        assertApproxEqAbs(msg.sender.balance, walletBalanceBeforeWtihdraw + balanceBeforeWithdraw, 0.01 ether);
    }

    function testRevertWhenUnauthorizedWithdrawal() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        pichiWalletNFT.mint{value: 0.5 ether}(user2);

        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pichiWalletNFT.withdraw(user1);
    }
}
