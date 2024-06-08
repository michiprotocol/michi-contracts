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

contract HelperSecondaryTest is Test {
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

        pichiWalletNFT = new PichiWalletNFT(0, 0);
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
            0,
            10000
        );
    }

    function testDepositFee() public {
        assertEq(pichiHelper.depositFee(), 0);
    }

    function testPrecision() public {
        assertEq(pichiHelper.feePrecision(), 10000);
    }

    function testChangeDepositFee() public {
        pichiHelper.setDepositFee(50);
        assertEq(pichiHelper.depositFee(), 50);
    }

    function testRevertWhenDepositFeeTooHigh() public {
        uint256 newFee = 50000;
        vm.expectRevert(abi.encodeWithSelector(PichiHelper.InvalidDepositFee.selector, newFee));
        pichiHelper.setDepositFee(newFee);
    }

    function testFeeReceiver() public {
        address feeRecipient = vm.addr(5);
        assertEq(pichiHelper.feeReceiver(), feeRecipient);
    }

    function testChangeFeeReceiver() public {
        address newFeeRecipient = vm.addr(6);
        pichiHelper.setFeeReceiver(newFeeRecipient);
        assertEq(pichiHelper.feeReceiver(), newFeeRecipient);
    }

    function testAddApprovedToken() public {
        pichiHelper.addApprovedToken(address(mockYT));
        assertEq(pichiHelper.approvedToken(address(mockYT)), true);
        assertEq(pichiHelper.listApprovedTokens(0), address(mockYT));
    }

    function testRemoveApprovedToken() public {
        address randomAddress1 = vm.addr(7);
        address randomAddress2 = vm.addr(8);
        address randomAddress3 = vm.addr(9);

        pichiHelper.addApprovedToken(randomAddress1);
        pichiHelper.addApprovedToken(randomAddress2);
        pichiHelper.addApprovedToken(randomAddress3);

        assertEq(pichiHelper.approvedToken(randomAddress1), true);
        assertEq(pichiHelper.approvedToken(randomAddress2), true);
        assertEq(pichiHelper.approvedToken(randomAddress3), true);
        assertEq(pichiHelper.listApprovedTokens(0), randomAddress1);
        assertEq(pichiHelper.listApprovedTokens(1), randomAddress2);
        assertEq(pichiHelper.listApprovedTokens(2), randomAddress3);

        pichiHelper.removeApprovedToken(randomAddress1);
        assertEq(pichiHelper.approvedToken(randomAddress1), false);
    }
}
