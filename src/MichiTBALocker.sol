// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import "tokenbound/src/AccountV3Upgradable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title MichiTBALocker
 *     @dev Implementation of a locker contract to hold Michi Wallet NFTs that are protocol
 *     owned. Includes functions to execute transactions on ERC-6551 accounts (TBA) without having to withdraw.
 *     If there are executions that cannot originate from a contract, a function to withdraw NFTs is available.
 */
contract MichiTBALocker is AccessControl {
    /// @notice Minter role
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    /// @notice error when array length is not matching
    error ArrayLengthMismatch();

    /// @notice error when NFT is not owned by this contract
    error NotOwned(address collection, uint256 tokenId);

    /// @notice event emitted when a successful transaction is executed on a TBA
    event TBAExecuted(address indexed tba, address to, uint256 value, bytes data, uint8 operation);

    /// @notice event emitted when an NFT has been withdrawn from this contract
    event NFTWithdrawn(address indexed recipient, address indexed collection, uint256 indexed tokenId);

    /// @dev Constructor for MichiPointsMinter contract
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(EXECUTOR_ROLE, msg.sender);
    }

    /// @dev Allows for ERC721 tokens to be received
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev Initiate transactions from TBAs held by this contract
    /// @param tba address of the tba
    /// @param to transaction's destination contract
    /// @param value native value of the transaction
    /// @param data encoded data for the transaction
    /// @param operation type of operation
    function executeTBA(address tba, address to, uint256 value, bytes calldata data, uint8 operation)
        public
        onlyRole(EXECUTOR_ROLE)
    {
        // get tba ownership nft
        (, address collection, uint256 tokenId) = AccountV3Upgradable(payable(tba)).token();

        // verify nft owner is this contract
        if (IERC721(collection).ownerOf(tokenId) != address(this)) revert NotOwned(collection, tokenId);

        AccountV3Upgradable(payable(tba)).execute(to, value, data, operation);

        emit TBAExecuted(tba, to, value, data, operation);
    }

    /// @dev Batch initiate transactions from TBAs held by this contract
    /// @param tbas address array of the tba
    /// @param toArray array of destination contracts
    /// @param values array of native values for the transactions
    /// @param calldatas array of encoded data for the transaction
    /// @param operations array of operation types
    function batchExecuteTBA(
        address[] calldata tbas,
        address[] calldata toArray,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        uint8[] calldata operations
    ) external onlyRole(EXECUTOR_ROLE) {
        console.log("done");
        if (
            tbas.length != toArray.length || toArray.length != values.length || values.length != calldatas.length
                || calldatas.length != operations.length
        ) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < tbas.length; i++) {
            executeTBA(tbas[i], toArray[i], values[i], calldatas[i], operations[i]);
        }
    }

    /// @dev Emergency withdraw of NFT if there are transactions that cannot be executed by this contract
    /// @param receiver address of the receiver
    /// @param collection nft collection to withdraw
    /// @param tokenId tokenId to withdraw
    function withdrawNFT(address receiver, address collection, uint256 tokenId) public onlyRole(EXECUTOR_ROLE) {
        if (IERC721(collection).ownerOf(tokenId) != address(this)) revert NotOwned(collection, tokenId);

        IERC721(collection).safeTransferFrom(address(this), receiver, tokenId);

        emit NFTWithdrawn(receiver, collection, tokenId);
    }

    /// @dev Emergency batch withdraw of NFTs if there are transactions that cannot be executed by this contract
    /// @param receiver address of the receiver
    /// @param collections array of nft collections to withdraw
    /// @param tokenIds array of tokenIds to withdraw
    function batchWithdrawNFT(address receiver, address[] calldata collections, uint256[] calldata tokenIds)
        external
        onlyRole(EXECUTOR_ROLE)
    {
        if (collections.length != tokenIds.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < collections.length; i++) {
            withdrawNFT(receiver, collections[i], tokenIds[i]);
        }
    }

    /// @dev Grant executor role that can execute TBA transactions
    /// @param user address of the executor to add
    function grantExecutorRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(EXECUTOR_ROLE, user);
    }

    /// @dev Revoke executor role that can execute TBA transactions
    /// @param user address of the executor to remove
    function revokeExecutorRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(EXECUTOR_ROLE, user);
    }
}
