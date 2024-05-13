// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "erc6551/ERC6551Registry.sol";

import "tokenbound/src/AccountV3.sol";
import "tokenbound/src/AccountV3Upgradable.sol";
import "tokenbound/src/AccountProxy.sol";
import "tokenbound/src/AccountGuardian.sol";

import "tokenbound/lib/multicall-authenticated/src/Multicall3.sol";

import "src/MichiWalletNFT.sol";
import {MichiHelper} from "src/MichiHelper.sol";
import "src/MichiWalletReceiptNFT.sol";
import "src/MichiTokenizeRequestor.sol";

import "src/MichiTBALocker.sol";
import "test/TestContracts/TestAirdropClaim.sol";
import "test/TestTokens/MockAirdropToken.sol";

contract TBALockerTest is Test {
    // wallet contracts
    MichiWalletNFT public michiWalletNFT;
    MichiHelper public michiHelper;

    // erc6551 contracts
    Multicall3 public multicall;
    AccountV3Upgradable public upgradeableImplementation;
    AccountGuardian public guardian;
    AccountProxy public proxy;
    ERC6551Registry public registry;

    // tokenize contracts
    MichiTokenizeRequestor public michiTokenizeRequestor;
    MichiWalletReceiptNFT public michiWalletReceiptNFT;

    // tba locker
    MichiTBALocker public michiTBALocker;

    // test airdrop token and claim contract
    MockAirdropToken public airdropToken;
    TestAirdropClaim public airdropContract;

    function setUp() public {
        // placeholders
        address feeRecipient = vm.addr(5);

        // deploy wallet and erc6551 contracts
        michiWalletNFT = new MichiWalletNFT(0, 0);
        registry = new ERC6551Registry();
        guardian = new AccountGuardian(address(this));
        multicall = new Multicall3();
        upgradeableImplementation =
            new AccountV3Upgradable(address(1), address(multicall), address(registry), address(guardian));
        proxy = new AccountProxy(address(guardian), address(upgradeableImplementation));

        michiHelper = new MichiHelper(
            address(registry),
            address(upgradeableImplementation),
            address(proxy),
            address(michiWalletNFT),
            feeRecipient,
            0,
            10000
        );

        // deploy tba locker
        michiTBALocker = new MichiTBALocker();

        // deploy tokenized request and michi wallet receipt nft
        michiWalletReceiptNFT = new MichiWalletReceiptNFT();
        michiTokenizeRequestor = new MichiTokenizeRequestor(address(michiTBALocker), address(michiWalletReceiptNFT));

        // deploy mock airdrop token and claim contract
        airdropToken = new MockAirdropToken();
        airdropContract = new TestAirdropClaim(address(airdropToken));

        // mint tokens to claim contract
        airdropToken.mint(address(airdropContract), 100000 ether);

        // add michi wallet nft to approved collections
        michiTokenizeRequestor.addApprovedCollection(address(michiWalletNFT));

        // give michi tokenize requestor minting privilege on reciept nft
        michiWalletReceiptNFT.grantMinterRole(address(michiTokenizeRequestor));
    }

    function testClaimAirdropFromTBA() public {
        // create wallet
        address user1 = vm.addr(1);
        uint256 index = michiWalletNFT.currentIndex();

        vm.prank(user1);
        michiHelper.createWallet(1);

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index);

        // create request
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba);

        // check that tba locker owns MichiWalletNFT
        assertEq(michiWalletNFT.ownerOf(index), address(michiTBALocker));

        // add allocation to tba associated with MichiWalletNFT
        airdropContract.setAllocation(tba, 1000 ether);
        assertEq(airdropContract.allocationByAddress(tba), 1000 ether);

        // execute claim from locker contract
        bytes memory transactionData = abi.encodeWithSignature("claim()");
        michiTBALocker.executeTBA(tba, address(airdropContract), 0, transactionData, 0);
        assertEq(airdropToken.balanceOf(tba), 1000 ether);
    }

    function testBatchClaim() public {
        // create 2 wallets
        address user1 = vm.addr(1);
        uint256 index1 = michiWalletNFT.currentIndex();
        uint256 index2 = index1 + 1;

        vm.prank(user1);
        michiHelper.createWallet(2);

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba1 = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index1);
        address tba2 = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index2);

        // create request
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba1);
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba2);

        // check that tba locker owns both MichiWalletNFT
        assertEq(michiWalletNFT.ownerOf(index1), address(michiTBALocker));
        assertEq(michiWalletNFT.ownerOf(index2), address(michiTBALocker));

        // add allocation to tba associated with MichiWalletNFT
        airdropContract.setAllocation(tba1, 1000 ether);
        airdropContract.setAllocation(tba2, 1000 ether);
        assertEq(airdropContract.allocationByAddress(tba1), 1000 ether);
        assertEq(airdropContract.allocationByAddress(tba2), 1000 ether);

        // execute batch claim from locker contract
        bytes memory transactionData = abi.encodeWithSignature("claim()");
        address[] memory a = new address[](2);
        a[0] = tba1;
        a[1] = tba2;

        address[] memory b = new address[](2);
        b[0] = address(airdropContract);
        b[1] = address(airdropContract);

        uint256[] memory c = new uint256[](2);
        c[0] = 0;
        c[1] = 0;

        bytes[] memory d = new bytes[](2);
        d[0] = transactionData;
        d[1] = transactionData;

        uint8[] memory e = new uint8[](2);
        e[0] = 0;
        e[1] = 0;

        michiTBALocker.batchExecuteTBA(a, b, c, d, e);
        assertEq(airdropToken.balanceOf(tba1), 1000 ether);
        assertEq(airdropToken.balanceOf(tba2), 1000 ether);
    }

    function testWithdrawNFT() public {
        // create wallet
        address user1 = vm.addr(1);
        uint256 index = michiWalletNFT.currentIndex();

        vm.prank(user1);
        michiHelper.createWallet(1);

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index);

        // create request
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba);

        // check that tba locker owns MichiWalletNFT
        assertEq(michiWalletNFT.ownerOf(index), address(michiTBALocker));

        // withdraw NFT
        michiTBALocker.withdrawNFT(user1, address(michiWalletNFT), index);
        assertEq(michiWalletNFT.ownerOf(index), user1);

        // revert if trying to withdraw an unowned nft
        vm.expectRevert(abi.encodeWithSelector(MichiTBALocker.NotOwned.selector, address(michiWalletNFT), index));
        michiTBALocker.withdrawNFT(user1, address(michiWalletNFT), index);
    }

    function testBatchWithdraw() public {
        // create 2 wallets
        address user1 = vm.addr(1);
        uint256 index1 = michiWalletNFT.currentIndex();
        uint256 index2 = index1 + 1;

        vm.prank(user1);
        michiHelper.createWallet(2);

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba1 = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index1);
        address tba2 = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index2);

        // create request
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba1);
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba2);

        // check that tba locker owns both MichiWalletNFT
        assertEq(michiWalletNFT.ownerOf(index1), address(michiTBALocker));
        assertEq(michiWalletNFT.ownerOf(index2), address(michiTBALocker));

        address[] memory a = new address[](2);
        a[0] = address(michiWalletNFT);
        a[1] = address(michiWalletNFT);

        uint256[] memory b = new uint256[](2);
        b[0] = index1;
        b[1] = index2;

        michiTBALocker.batchWithdrawNFT(user1, a, b);
        assertEq(michiWalletNFT.ownerOf(index1), user1);
        assertEq(michiWalletNFT.ownerOf(index2), user1);
    }

    function testRevertUnauthorizedExecutor() public {
        // create wallet
        address user1 = vm.addr(1);
        uint256 index = michiWalletNFT.currentIndex();

        vm.prank(user1);
        michiHelper.createWallet(1);

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index);

        // create request
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba);

        // check that tba locker owns MichiWalletNFT
        assertEq(michiWalletNFT.ownerOf(index), address(michiTBALocker));

        // add allocation to tba associated with MichiWalletNFT
        airdropContract.setAllocation(tba, 1000 ether);
        assertEq(airdropContract.allocationByAddress(tba), 1000 ether);

        // execute claim from locker contract
        bytes memory transactionData = abi.encodeWithSignature("claim()");
        vm.prank(user1);
        vm.expectRevert();
        michiTBALocker.executeTBA(tba, address(airdropContract), 0, transactionData, 0);
    }

    function testRevertArrayMismatch() public {
        // create 2 wallets
        address user1 = vm.addr(1);
        uint256 index1 = michiWalletNFT.currentIndex();
        uint256 index2 = index1 + 1;

        vm.prank(user1);
        michiHelper.createWallet(2);

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba1 = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index1);
        address tba2 = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index2);

        // create request
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba1);
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba2);

        // check that tba locker owns both MichiWalletNFT
        assertEq(michiWalletNFT.ownerOf(index1), address(michiTBALocker));
        assertEq(michiWalletNFT.ownerOf(index2), address(michiTBALocker));

        // add allocation to tba associated with MichiWalletNFT
        airdropContract.setAllocation(tba1, 1000 ether);
        airdropContract.setAllocation(tba2, 1000 ether);
        assertEq(airdropContract.allocationByAddress(tba1), 1000 ether);
        assertEq(airdropContract.allocationByAddress(tba2), 1000 ether);

        // execute batch claim from locker contract
        bytes memory transactionData = abi.encodeWithSignature("claim()");
        address[] memory a = new address[](2);
        a[0] = tba1;
        a[1] = tba2;

        address[] memory b = new address[](2);
        b[0] = address(airdropContract);
        b[1] = address(airdropContract);

        uint256[] memory c = new uint256[](2);
        c[0] = 0;
        c[1] = 0;

        bytes[] memory d = new bytes[](2);
        d[0] = transactionData;
        d[1] = transactionData;

        uint8[] memory e = new uint8[](1);
        e[0] = 0;

        vm.expectRevert(MichiTBALocker.ArrayLengthMismatch.selector);
        michiTBALocker.batchExecuteTBA(a, b, c, d, e);
    }
}
