// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "tokenbound/src/AccountV3Upgradable.sol";

import "./interfaces/IMichiWalletReceiptNFT.sol";

/**
 * @title MichiTokenizeRequestor
 *     @dev Implementation of a request contract. Users can create requests to tokenize
 *     points earned in ERC-6551 accounts (TBAs). Once the request is made, the tokenized
 *     points will be minted and the Michi Wallet NFT will be transferred to the MichiTBALocker.
 */
contract MichiTokenizeRequestor is Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    /// @notice counter to create a unique id for each request
    Counters.Counter private _requestIds;

    struct Request {
        address requestor;
        address michiWalletAddress;
        uint256 requestId;
    }

    /// @notice address of the MichiTBALocker
    address public michiTBALocker;

    /// @notice instance of the receipt NFT
    IMichiWalletReceiptNFT public michiWalletReceiptNFT;

    /// @notice enter id to retrieve request
    mapping(uint256 => Request) public idToRequest;

    /// @notice mapping of approved Michi Wallet collections
    mapping(address => bool) public approvedCollections;

    /// @notice error emitted when an unapproved nft collection is transferred
    error UnapprovedCollection(address collection);

    /// @notice error returned when 6551 wallet owner is not sender
    error UnauthorizedCaller(address caller);

    /// @notice error returned when approving an already approved collection
    error CollectionAlreadyApproved(address collection);

    /// @notice error returned when removing an unapproved collection
    error CollectionNotApproved(address collection);

    /// @notice event emitted when a new tokenize request is created
    event NewTokenizeRequest(address indexed requester, address indexed michiWallet, uint256 indexed requestId);

    /// @notice event emitted when a new collection is added
    event CollectionApproved(address indexed collection);

    /// @notice event emitted when a collection has been removed
    event CollectionRemoved(address indexed collection);

    /// @dev Constructor for MichiTokenizeRequestor contract
    /// @param michiTBALocker_ address of the MichiTBALocker
    /// @param michiWalletReceiptNFT_ address of the MichiWalletReceiptNFT
    constructor(address michiTBALocker_, address michiWalletReceiptNFT_) {
        michiTBALocker = michiTBALocker_;
        michiWalletReceiptNFT = IMichiWalletReceiptNFT(michiWalletReceiptNFT_);
    }

    /// @dev Initiate tokenized points request
    /// @param michiWalletAddress tba address that holds points to be tokenized
    function createTokenizePointsRequest(address michiWalletAddress) external {
        // get tba ownership nft
        (, address tokenContract, uint256 tokenId) = AccountV3Upgradable(payable(michiWalletAddress)).token();

        if (!approvedCollections[tokenContract]) revert UnapprovedCollection(tokenContract);

        // verify nft owner is caller
        if (IERC721(tokenContract).ownerOf(tokenId) != msg.sender) revert UnauthorizedCaller(msg.sender);

        // transfer in michi wallet nft
        IERC721(tokenContract).safeTransferFrom(msg.sender, michiTBALocker, tokenId);

        _requestIds.increment();
        uint256 newRequestId = _requestIds.current();
        idToRequest[newRequestId] = Request(msg.sender, michiWalletAddress, newRequestId);

        // mint the user a receipt NFT of same index
        // in case other projects (such as AVSs) airdrop tokens to previous EL points earners
        michiWalletReceiptNFT.mint(msg.sender, tokenId);

        emit NewTokenizeRequest(msg.sender, michiWalletAddress, newRequestId);
    }

    /// @dev Add new collection
    /// @param newCollection address of the new collection
    function addApprovedCollection(address newCollection) external onlyOwner {
        if (approvedCollections[newCollection]) revert CollectionAlreadyApproved(newCollection);
        approvedCollections[newCollection] = true;

        emit CollectionApproved(newCollection);
    }

    /// @dev Remove an approved collection
    /// @param collectionToRemove address of the collection to remove
    function removeApprovedCollection(address collectionToRemove) external onlyOwner {
        if (!approvedCollections[collectionToRemove]) revert CollectionNotApproved(collectionToRemove);
        approvedCollections[collectionToRemove] = false;

        emit CollectionRemoved(collectionToRemove);
    }

    /// @dev Set a new MichiTBALocker address
    /// @param newMichiTBALockerAddress address of the new MichiTBALocker
    function setMichiTBALockerAddress(address newMichiTBALockerAddress) external onlyOwner {
        michiTBALocker = newMichiTBALockerAddress;
    }
}
