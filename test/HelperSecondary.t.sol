// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "erc6551/ERC6551Registry.sol";

import "tokenbound/src/AccountV3.sol";
import "tokenbound/src/AccountProxy.sol";

import "./TestContracts/MockYT.sol";

import "src/MichiBackpack.sol";
import {MichiHelper} from "src/MichiHelper.sol";

contract HelperSecondaryTest is Test {
    MichiBackpack public michiBackpack;
    MichiHelper public michiHelper;
    MockYT public mockYT;
    AccountV3 public implementation;
    ERC6551Registry public registry;

    function setUp() public {
        address feeRecipient = vm.addr(5);

        michiBackpack = new MichiBackpack(0, 0);
        registry = new ERC6551Registry();
        implementation = new AccountV3(address(1), address(1), address(1), address(1));
        mockYT = new MockYT();
        michiHelper =
            new MichiHelper(address(registry), address(implementation), address(michiBackpack), feeRecipient, 0, 10000);
    }

    function testDepositFee() public {
        assertEq(michiHelper.depositFee(), 0);
    }

    function testPrecision() public {
        assertEq(michiHelper.feePrecision(), 10000);
    }

    function testChangeDepositFee() public {
        michiHelper.setDepositFee(50);
        assertEq(michiHelper.depositFee(), 50);
    }

    function testRevertWhenDepositFeeTooHigh() public {
        uint256 newFee = 50000;
        vm.expectRevert(abi.encodeWithSelector(MichiHelper.InvalidDepositFee.selector, newFee));
        michiHelper.setDepositFee(newFee);
    }

    function testFeeReceiver() public {
        address feeRecipient = vm.addr(5);
        assertEq(michiHelper.feeReceiver(), feeRecipient);
    }

    function testChangeFeeReceiver() public {
        address newFeeRecipient = vm.addr(6);
        michiHelper.setFeeReceiver(newFeeRecipient);
        assertEq(michiHelper.feeReceiver(), newFeeRecipient);
    }

    function testAddApprovedToken() public {
        michiHelper.addApprovedToken(address(mockYT));
        assertEq(michiHelper.approvedToken(address(mockYT)), true);
        assertEq(michiHelper.listApprovedTokens(0), address(mockYT));
    }

    function testRemoveApprovedToken() public {
        address randomAddress1 = vm.addr(7);
        address randomAddress2 = vm.addr(8);
        address randomAddress3 = vm.addr(9);

        michiHelper.addApprovedToken(randomAddress1);
        michiHelper.addApprovedToken(randomAddress2);
        michiHelper.addApprovedToken(randomAddress3);

        assertEq(michiHelper.approvedToken(randomAddress1), true);
        assertEq(michiHelper.approvedToken(randomAddress2), true);
        assertEq(michiHelper.approvedToken(randomAddress3), true);
        assertEq(michiHelper.listApprovedTokens(0), randomAddress1);
        assertEq(michiHelper.listApprovedTokens(1), randomAddress2);
        assertEq(michiHelper.listApprovedTokens(2), randomAddress3);

        michiHelper.removeApprovedToken(randomAddress1);
        assertEq(michiHelper.approvedToken(randomAddress1), false);
    }
}
