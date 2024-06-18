// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "erc6551/ERC6551Registry.sol";

import "tokenbound/src/AccountV3.sol";
import "tokenbound/src/AccountV3Upgradable.sol";
import "tokenbound/src/AccountProxy.sol";
import "tokenbound/src/AccountGuardian.sol";

import "tokenbound/lib/multicall-authenticated/src/Multicall3.sol";

import "./TestContracts/MockYT.sol";

import "src/PichiWalletNFT.sol";
import {PichiHelper} from "src/PichiHelper.sol";

contract HelperCostTest is Test {
    PichiWalletNFT public pichiWalletNFT;
    PichiHelper public pichiHelper;
    MockYT public mockYT;

    Multicall3 public multicall;
    AccountV3 public implementation;
    AccountV3Upgradable public upgradeableImplementation;
    AccountGuardian public guardian;
    AccountProxy public proxy;
    ERC6551Registry public registry;

    function setUp() public {
        address feeRecipient = vm.addr(5);

        pichiWalletNFT = new PichiWalletNFT(0, 1 ether);
        registry = new ERC6551Registry();
        guardian = new AccountGuardian(address(this));
        multicall = new Multicall3();
        upgradeableImplementation =
            new AccountV3Upgradable(address(1), address(multicall), address(registry), address(guardian));
        proxy = new AccountProxy(address(guardian), address(upgradeableImplementation));
        mockYT = new MockYT();
        pichiHelper = new PichiHelper(
            address(registry),
            address(upgradeableImplementation),
            address(proxy),
            address(pichiWalletNFT),
            feeRecipient,
            0
        );
    }

    function testCreateWallet() public {
        address user1 = vm.addr(1);
        uint256 index = pichiWalletNFT.currentIndex();

        // compute predicted address using expected id
        address computedAddress = registry.account(address(proxy), 0, block.chainid, address(pichiWalletNFT), index);

        vm.deal(user1, 10 ether);

        vm.prank(user1);
        pichiHelper.createWallet{value: 1 ether}(1);

        // check that #0 minted to user1
        assertEq(pichiWalletNFT.ownerOf(index), user1);

        // check that predicted address is owned by user1
        AccountV3Upgradable account = AccountV3Upgradable(payable(computedAddress));
        assertEq(account.owner(), user1);
    }

    function testDepositAndWithdraw() public {
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        uint256 index = pichiWalletNFT.currentIndex();

        // compute predicted address using expected id
        address computedAddress = registry.account(address(proxy), 0, block.chainid, address(pichiWalletNFT), index);

        vm.deal(user1, 10 ether);
        vm.prank(user1);
        pichiHelper.createWallet{value: 1 ether}(1);

        // mint mock YT tokens
        mockYT.mint(user1, 10 ether);
        mockYT.mint(user2, 10 ether);
        assertEq(mockYT.balanceOf(user1), 10 ether);
        assertEq(mockYT.balanceOf(user2), 10 ether);

        // user should fail to deposit token before it is approved
        mockYT.approve(address(pichiHelper), 10 ether);
        vm.expectRevert(abi.encodeWithSelector(PichiHelper.UnauthorizedToken.selector, address(mockYT)));
        vm.prank(user1);
        pichiHelper.depositToken(address(mockYT), computedAddress, 5 ether, true);

        // add test YT to approved tokens list
        pichiHelper.addApprovedToken(address(mockYT));
        assertEq(pichiHelper.approvedToken(address(mockYT)), true);

        uint256 totalDepositAmount = 5 ether;
        uint256 feeAmount = totalDepositAmount * pichiHelper.depositFee() / pichiHelper.feePrecision();
        uint256 depositAmountAfterFees = totalDepositAmount - feeAmount;

        // user2 should fail to deposit YT
        vm.prank(user2);
        mockYT.approve(address(pichiHelper), 10 ether);
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(PichiHelper.UnauthorizedUser.selector, user2));
        pichiHelper.depositToken(address(mockYT), computedAddress, 5 ether, true);

        // user1 should succeed in depositing YT

        vm.prank(user1);
        mockYT.approve(address(pichiHelper), 10 ether);
        vm.prank(user1);
        pichiHelper.depositToken(address(mockYT), computedAddress, 5 ether, true);

        assertEq(mockYT.balanceOf(computedAddress), depositAmountAfterFees);
        assertEq(mockYT.balanceOf(pichiHelper.feeReceiver()), feeAmount);
        assertEq(pichiHelper.depositsByAccountByToken(computedAddress, address(mockYT)), depositAmountAfterFees);
        assertEq(pichiHelper.depositsByToken(address(mockYT)), depositAmountAfterFees);
        assertEq(pichiHelper.feesCollectedByToken(address(mockYT)), feeAmount);

        // user2 should fail transfering out YT
        AccountV3Upgradable account = AccountV3Upgradable(payable(computedAddress));
        bytes memory transferCall = abi.encodeWithSignature("transfer(address,uint256)", user1, depositAmountAfterFees);
        vm.prank(user2);
        vm.expectRevert(NotAuthorized.selector);
        account.execute(address(mockYT), 0, transferCall, 0);

        // user1 should success transfering out YT
        uint256 balanceBeforeWithdraw = mockYT.balanceOf(user1);
        vm.prank(user1);
        account.execute(address(mockYT), 0, transferCall, 0);
        assertEq(mockYT.balanceOf(user1), depositAmountAfterFees + balanceBeforeWithdraw);
    }
}
