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

contract TokenizeRequestTest is Test {
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
    address public michiTBALocker;

    function setUp() public {
        // placeholders
        address feeRecipient = vm.addr(5);
        michiTBALocker = vm.addr(6);

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

        // deploy tokenized request and michi wallet receipt nft
        michiWalletReceiptNFT = new MichiWalletReceiptNFT();
        michiTokenizeRequestor = new MichiTokenizeRequestor(michiTBALocker, address(michiWalletReceiptNFT));

        // add michi wallet nft to approved collections
        michiTokenizeRequestor.addApprovedCollection(address(michiWalletNFT));

        // give michi tokenize requestor minting privilege on reciept nft
        michiWalletReceiptNFT.grantMinterRole(address(michiTokenizeRequestor));
    }

    function testCreateTokenizePointsRequest() public {
        // create wallet
        address user1 = vm.addr(1);
        uint256 index = michiWalletNFT.currentIndex();

        vm.prank(user1);
        michiHelper.createWallet(1);
        assertEq(michiWalletNFT.ownerOf(index), user1);

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index);

        // create request
        vm.prank(user1);
        michiTokenizeRequestor.createTokenizePointsRequest(tba);

        // check that tba locker owns MichiWalletNFT
        assertEq(michiWalletNFT.ownerOf(index), michiTBALocker);

        // check that user1 is minted MichiWalletReceiptNFT of same index
        assertEq(michiWalletReceiptNFT.ownerOf(index), user1);

        // retrieve request struct
        (address requestor, address michiWalletAddress, uint256 requestId) = michiTokenizeRequestor.idToRequest(1);
        assertEq(requestor, user1);
        assertEq(michiWalletAddress, tba);
        assertEq(requestId, 1);
    }

    function testSetNewTBALocker() public {
        address currentTBALockerAddress = vm.addr(6);
        address newTBALockerAddress = vm.addr(10);

        // should revert when zero address
        vm.expectRevert(abi.encodeWithSelector(MichiTokenizeRequestor.InvalidTBALockerAddress.selector, address(0)));
        michiTokenizeRequestor.setMichiTBALockerAddress(address(0));

        // should revert when setting inputting current address
        vm.expectRevert(
            abi.encodeWithSelector(MichiTokenizeRequestor.InvalidTBALockerAddress.selector, currentTBALockerAddress)
        );
        michiTokenizeRequestor.setMichiTBALockerAddress(currentTBALockerAddress);

        // should pass when inputting correct address
        michiTokenizeRequestor.setMichiTBALockerAddress(newTBALockerAddress);
    }

    function testRevertUnownedWallet() public {
        // user 1 create wallet
        address user1 = vm.addr(1);
        uint256 user1index = michiWalletNFT.currentIndex();

        vm.prank(user1);
        michiHelper.createWallet(1);
        assertEq(michiWalletNFT.ownerOf(user1index), user1);

        // user 2 create wallet
        address user2 = vm.addr(2);
        uint256 user2index = michiWalletNFT.currentIndex();

        vm.prank(user2);
        michiHelper.createWallet(1);
        assertEq(michiWalletNFT.ownerOf(user2index), user2);

        // user1 give approval and compute user 2's tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address user2tba = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), user2index);

        // revert when creating request with user 2 nft
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(MichiTokenizeRequestor.UnauthorizedCaller.selector, user1));
        michiTokenizeRequestor.createTokenizePointsRequest(user2tba);
    }

    function testRevertUnapprovedCollection() public {
        // user 1 create wallet
        address user1 = vm.addr(1);
        uint256 index = michiWalletNFT.currentIndex();

        vm.prank(user1);
        michiHelper.createWallet(1);
        assertEq(michiWalletNFT.ownerOf(index), user1);

        // remove michi wallet nft from approved collections
        michiTokenizeRequestor.removeApprovedCollection(address(michiWalletNFT));

        // give approval and compute tba
        vm.prank(user1);
        michiWalletNFT.setApprovalForAll(address(michiTokenizeRequestor), true);

        address tba = registry.account(address(proxy), 0, block.chainid, address(michiWalletNFT), index);

        // revert when creating request with approved collection
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(MichiTokenizeRequestor.UnapprovedCollection.selector, address(michiWalletNFT))
        );
        michiTokenizeRequestor.createTokenizePointsRequest(tba);
    }
}
