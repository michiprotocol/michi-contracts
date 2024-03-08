// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/MichiWalletNFT.sol";

contract WalletNFTTest2 is Test {
    MichiWalletNFT public michiWalletNFT;

    function setUp() public {
        michiWalletNFT = new MichiWalletNFT(0, 0.5 ether);
    }

    function testPrice() public {
        assertEq(michiWalletNFT.mintPrice(), 0.5 ether);
    }

    function testPriceChange() public {
        michiWalletNFT.setMintPrice(1 ether);
        assertEq(michiWalletNFT.mintPrice(), 1 ether);
    }

    function testMint() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        uint256 idToMint = michiWalletNFT.getCurrentIndex();
        uint256 supplyBeforeMint = michiWalletNFT.totalSupply();
        vm.prank(user1);
        michiWalletNFT.mint{value: 0.5 ether}(user2);

        assertEq(michiWalletNFT.getCurrentIndex(), idToMint + 1);
        assertEq(michiWalletNFT.totalSupply(), supplyBeforeMint + 1);
        assertEq(michiWalletNFT.ownerOf(idToMint), user2);
        assertEq(michiWalletNFT.balanceOf(user2), 1);
    }

    function testRevertWhenIncorrectValueSent() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MichiWalletNFT.InvalidPayableAmount.selector, 1 ether));
        michiWalletNFT.mint{value: 1 ether}(user2);
    }

    function testWithdrawBalance() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        michiWalletNFT.mint{value: 0.5 ether}(user2);

        uint256 walletBalanceBeforeWtihdraw = address(michiWalletNFT).balance;
        uint256 balanceBeforeWithdraw = msg.sender.balance;
        michiWalletNFT.withdraw(msg.sender);
        assertEq(address(michiWalletNFT).balance, 0);
        assertApproxEqAbs(msg.sender.balance, walletBalanceBeforeWtihdraw + balanceBeforeWithdraw, 0.01 ether);
    }

    function testRevertWhenUnauthorizedWithdrawal() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        vm.deal(user1, 2 ether);

        vm.prank(user1);
        michiWalletNFT.mint{value: 0.5 ether}(user2);

        vm.prank(user1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        michiWalletNFT.withdraw(user1);
    }
}
