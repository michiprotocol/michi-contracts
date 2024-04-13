// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "erc6551/ERC6551Registry.sol";

import "tokenbound/src/AccountV3.sol";
import "tokenbound/src/AccountV3Upgradable.sol";
import "tokenbound/src/AccountProxy.sol";
import "tokenbound/src/AccountGuardian.sol";

import "tokenbound/lib/multicall-authenticated/src/Multicall3.sol";

import "../TestTokens/MockYT.sol";

import "src/MichiWalletNFT.sol";
import {MichiHelper} from "src/MichiHelper.sol";
import "src/MichiWalletReceiptNFT.sol";
import "src/MichiTokenizeRequestor.sol";

import "src/MichiTokenizedPointERC20.sol";
import "src/MichiPointsMinter.sol";

contract TokenizeMintTest is Test {
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
    MichiPointsMinter public michiPointsMinter;

    // tokenized points
    MichiTokenizedPointERC20 public melp; // michi eigenlayer point
    MichiTokenizedPointERC20 public mes; // michi ethena sats
    MichiTokenizedPointERC20 public mefp; // michi etherfi point

    // tba locker
    address public michiTBALocker;

    // fee recipient
    address public feeRecipient;

    // forks
    uint256 public ethfork;
    uint256 public basefork;

    function setUp() public {
        ethfork = vm.createFork("https://ethereum-rpc.publicnode.com");
        basefork = vm.createFork("https://base-rpc.publicnode.com");

        // placeholders
        feeRecipient = vm.addr(5);
        michiTBALocker = vm.addr(6);

        // deploy wallet and erc6551 contracts on eth
        vm.selectFork(ethfork);
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

        // deploy tokenized request and receipt nft on eth
        michiWalletReceiptNFT = new MichiWalletReceiptNFT();
        michiTokenizeRequestor = new MichiTokenizeRequestor(michiTBALocker, address(michiWalletReceiptNFT));

        // add michi wallet nft to approved collections
        michiTokenizeRequestor.addApprovedCollection(address(michiWalletNFT));

        // give tokenize requestor contract minter role on reciept nft
        michiWalletReceiptNFT.grantMinterRole(address(michiTokenizeRequestor));

        // deploy points minter and tokenized points on base
        vm.selectFork(basefork);
        michiPointsMinter = new MichiPointsMinter(feeRecipient, 100, 10000);
        melp = new MichiTokenizedPointERC20("Michi Eigenlayer Point", "MELP", address(michiPointsMinter));
        mes = new MichiTokenizedPointERC20("Michi Ethena Sats", "MES", address(michiPointsMinter));
        mefp = new MichiTokenizedPointERC20("Michi Ether.fi Point", "MEFP", address(michiPointsMinter));

        // add tokenized points to approved tokens list
        michiPointsMinter.addApprovedTokenizedPoint(address(melp));
        michiPointsMinter.addApprovedTokenizedPoint(address(mes));
        michiPointsMinter.addApprovedTokenizedPoint(address(mefp));
    }

    function testMintTokenizedPoints() public {
        vm.selectFork(ethfork);
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

        // for testing purposes, user 1's michi wallet has 10000 eigenlayer points, 50000 ethena sats, and 300 etherfi points

        // on base, execute tokenized points mint
        vm.selectFork(basefork);
        uint256 tokenizeFee = michiPointsMinter.tokenizeFee();
        uint256 precision = michiPointsMinter.precision();

        address[] memory a = new address[](3);
        a[0] = address(melp);
        a[1] = address(mes);
        a[2] = address(mefp);

        uint256[] memory b = new uint256[](3);
        b[0] = 10000 ether;
        b[1] = 50000 ether;
        b[2] = 300 ether;

        michiPointsMinter.mintTokenizedPoints(requestor, a, b, ethfork, requestId);
        uint256 melpFeeExpected = 10000 ether * tokenizeFee / precision;
        uint256 mesFeeExpected = 50000 ether * tokenizeFee / precision;
        uint256 mefpFeeExpected = 300 ether * tokenizeFee / precision;
        uint256 userMelpBalanceExpected = 10000 ether - melpFeeExpected;
        uint256 userMesBalanceExpected = 50000 ether - mesFeeExpected;
        uint256 userMefpBalanceExpected = 300 ether - mefpFeeExpected;

        // check if mappings and balances are correct
        assertEq(michiPointsMinter.feesByTokenizedPoint(address(melp)), melpFeeExpected);
        assertEq(michiPointsMinter.feesByTokenizedPoint(address(mes)), mesFeeExpected);
        assertEq(michiPointsMinter.feesByTokenizedPoint(address(mefp)), mefpFeeExpected);
        assertEq(melp.balanceOf(feeRecipient), melpFeeExpected);
        assertEq(mes.balanceOf(feeRecipient), mesFeeExpected);
        assertEq(mefp.balanceOf(feeRecipient), mefpFeeExpected);

        assertEq(melp.balanceOf(requestor), userMelpBalanceExpected);
        assertEq(mes.balanceOf(requestor), userMesBalanceExpected);
        assertEq(mefp.balanceOf(requestor), userMefpBalanceExpected);
    }

    function testRevertArrayLengthMismatch() public {
        vm.selectFork(ethfork);
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

        // retrieve request struct
        (address requestor, address michiWalletAddress, uint256 requestId) = michiTokenizeRequestor.idToRequest(1);

        // for testing purposes, user 1's michi wallet has 10000 eigenlayer points, 50000 ethena sats, and 300 etherfi points

        // on base, execute tokenized points mint
        vm.selectFork(basefork);

        address[] memory a = new address[](3);
        a[0] = address(melp);
        a[1] = address(mes);
        a[2] = address(mefp);

        uint256[] memory b = new uint256[](2);
        b[0] = 10000 ether;
        b[1] = 50000 ether;

        vm.expectRevert(MichiPointsMinter.ArrayLengthMismatch.selector);
        michiPointsMinter.mintTokenizedPoints(requestor, a, b, ethfork, requestId);
    }

    function testRevertInvalidToken() public {
        vm.selectFork(ethfork);
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

        // retrieve request struct
        (address requestor, address michiWalletAddress, uint256 requestId) = michiTokenizeRequestor.idToRequest(1);

        // for testing purposes, user 1's michi wallet has 10000 eigenlayer points, 50000 ethena sats, and 300 etherfi points

        // on base, execute tokenized points mint
        vm.selectFork(basefork);

        // remove mefp from approved tokens
        michiPointsMinter.removeTokenizedPoint(address(mefp));

        address[] memory a = new address[](3);
        a[0] = address(melp);
        a[1] = address(mes);
        a[2] = address(mefp);

        uint256[] memory b = new uint256[](3);
        b[0] = 10000 ether;
        b[1] = 50000 ether;
        b[2] = 300 ether;

        vm.expectRevert(abi.encodeWithSelector(MichiPointsMinter.UnapprovedToken.selector, address(mefp)));
        michiPointsMinter.mintTokenizedPoints(requestor, a, b, ethfork, requestId);
    }

    function testRevertZeroAmount() public {
        vm.selectFork(ethfork);
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

        // retrieve request struct
        (address requestor, address michiWalletAddress, uint256 requestId) = michiTokenizeRequestor.idToRequest(1);

        // for testing purposes, user 1's michi wallet has 10000 eigenlayer points, 50000 ethena sats, and 300 etherfi points

        // on base, execute tokenized points mint
        vm.selectFork(basefork);

        address[] memory a = new address[](3);
        a[0] = address(melp);
        a[1] = address(mes);
        a[2] = address(mefp);

        uint256[] memory b = new uint256[](3);
        b[0] = 10000 ether;
        b[1] = 50000 ether;
        b[2] = 0;

        vm.expectRevert(abi.encodeWithSelector(MichiPointsMinter.InvalidAmount.selector, b[2]));
        michiPointsMinter.mintTokenizedPoints(requestor, a, b, ethfork, requestId);
    }

    function testRevertInvalidTokenizeFee() public {
        vm.selectFork(basefork);

        vm.expectRevert(abi.encodeWithSelector(MichiPointsMinter.InvalidTokenizeFee.selector, 501));
        michiPointsMinter.setTokenizeFee(501);
    }

    function testRevertNotAdmin() public {
        address user1 = vm.addr(1);

        vm.selectFork(basefork);

        // successfully remove one tokenized point approval
        michiPointsMinter.removeTokenizedPoint(address(mefp));

        // revert when user 1 tries to add point approval
        vm.prank(user1);
        vm.expectRevert();
        michiPointsMinter.addApprovedTokenizedPoint(address(mefp));

        // revert when user 1 tries to set fee
        vm.prank(user1);
        vm.expectRevert();
        michiPointsMinter.setTokenizeFee(300);
    }
}
