// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "src/interfaces/IPichiMarketplace.sol";
import "src/libraries/SignatureAuthentication.sol";
import {Order, Listing, Offer} from "src/libraries/OrderTypes.sol";

/// @title PichiMarketplace
/// @dev NFT Marketplace for trading of ERC-6551 Accounts from Pichi Finance
/// @dev Utilizes EIP-712 signatures for off-chain signing and on-chain settlement of orders
contract PichiMarketplaceV2 is IPichiMarketplace, Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice contract domain separator for EIP-712 compliance
    bytes32 public domainSeparator;

    /// @notice address of wrapped ether
    address public weth;

    /// @notice address that receives marketplace fees generated from this contract
    address public marketplaceFeeRecipient;

    /// @notice marketplace fee that is divisible by precision
    uint256 public marketplaceFee;

    /// @notice denominator for marketplace fee
    uint256 public precision;

    /// @notice minimum order nonce for orders that can be settled
    mapping(address => uint256) public userMinOrderNonce;

    /// @notice mapping for if a user's order nonce has been executed or cancelled
    mapping(address => mapping(uint256 => bool)) public isUserNonceExecutedOrCancelled;

    /// @notice mapping for if a token is accepted as payment
    mapping(address => bool) public isCurrencyAccepted;

    /// @notice mapping for if a collection is accepted for trading
    mapping(address => bool) public isCollectionAccepted;

    /// @notice array of accepted currencies
    address[] public listAcceptedCurrencies;

    /// @notice array of accepted collections
    address[] public listAcceptedCollections;

    /// @notice Initializes contract variables during deployment
    function initialize(address weth_, address marketplaceFeeRecipient_, uint256 marketplaceFee_, uint256 precision_)
        external
        reinitializer(2)
    {
        if (weth_ == address(0) || marketplaceFeeRecipient_ == address(0)) revert InvalidAddress();
        if (precision_ == 0) revert InvalidValue();
        domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId, address verifyingContract)"),
                keccak256("PichiMarketplace"),
                keccak256(bytes("2")),
                block.chainid,
                address(this)
            )
        );
        weth = weth_;
        marketplaceFeeRecipient = marketplaceFeeRecipient_;
        marketplaceFee = marketplaceFee_;
        precision = precision_;
    }

    /// @notice Cancels all orders for a user by setting their userMinOrderNonce to minNonce specified
    /// @param minNonce Minimum nonce for orders that can be executed
    function cancelAllOrdersForCaller(uint256 minNonce) external override {
        if (minNonce <= userMinOrderNonce[msg.sender]) revert NonceLowerThanCurrent();

        userMinOrderNonce[msg.sender] = minNonce;

        emit AllOrdersCancelled(msg.sender, minNonce);
    }

    /// @notice Cancels specific order nonces for a user
    /// @param orderNonces Array of order nonces to mark as cancelled
    function cancelOrdersForCaller(uint256[] calldata orderNonces) external override {
        if (orderNonces.length == 0) revert ArrayEmpty();

        for (uint256 i = 0; i < orderNonces.length; i++) {
            if (orderNonces[i] <= userMinOrderNonce[msg.sender]) revert NonceLowerThanCurrent();
            if (isUserNonceExecutedOrCancelled[msg.sender][orderNonces[i]]) revert OrderAlreadyCancelled();
            isUserNonceExecutedOrCancelled[msg.sender][orderNonces[i]] = true;
        }

        emit OrdersCancelled(msg.sender, orderNonces);
    }

    /// @notice Called by buyer to execute a seller's listing
    /// @notice Listing must be for a collection that is accepted that is paid in an accepted currency
    /// @param listing Listing order data
    function executeListing(Listing calldata listing) external payable override {
        if (!isCurrencyAccepted[listing.order.currency]) revert CurrencyNotAccepted();
        if (!isCollectionAccepted[listing.order.collection]) revert CollectionNotAccepted();
        if (msg.sender == listing.seller) revert OrderCreatorCannotExecute();

        _validateListing(listing);

        if (msg.value != 0) {
            if (listing.order.currency != weth) revert CurrencyMismatch();
            _transferWalletForPayment(listing.order, listing.seller, msg.sender, true);
        } else {
            _transferWalletForPayment(listing.order, listing.seller, msg.sender, false);
        }

        isUserNonceExecutedOrCancelled[listing.seller][listing.nonce] = true;

        emit WalletPurchased(
            listing.seller,
            msg.sender,
            listing.order.collection,
            listing.order.currency,
            listing.order.tokenId,
            listing.order.amount,
            listing.nonce
        );
    }

    /// @notice Called by a seller to accept a buyer's offer
    /// @notice Listing must be for a collection that is accepted that is paid in an accepted currency
    /// @param offer Offer order data
    function acceptOffer(Offer calldata offer) external override {
        if (!isCurrencyAccepted[offer.order.currency]) revert CurrencyNotAccepted();
        if (!isCollectionAccepted[offer.order.collection]) revert CollectionNotAccepted();
        if (msg.sender == offer.buyer) revert OrderCreatorCannotExecute();

        _validateOffer(offer);

        _transferWalletForPayment(offer.order, msg.sender, offer.buyer, false);

        isUserNonceExecutedOrCancelled[offer.buyer][offer.nonce] = true;

        emit WalletPurchased(
            msg.sender,
            offer.buyer,
            offer.order.collection,
            offer.order.currency,
            offer.order.tokenId,
            offer.order.amount,
            offer.nonce
        );
    }

    /// @notice Called by contract owner to set a new marketplace fee
    /// @notice Fee cannot be greater than 10%
    /// @param newFee The new marketplace fee
    function setMarketplaceFee(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert InvalidFee();
        uint256 oldFee = marketplaceFee;
        marketplaceFee = newFee;

        emit NewMarketplaceFee(newFee, oldFee);
    }

    /// @notice Called by contract owner to set a new fee recipient for marketplace fees
    /// @param newFeeRecipient Address of new fe recipient
    function setMarketplaceFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == address(0) || newFeeRecipient == marketplaceFeeRecipient) revert InvalidAddress();
        address oldFeeRecipient = marketplaceFeeRecipient;
        marketplaceFeeRecipient = newFeeRecipient;

        emit NewMarketplaceFeeRecipient(newFeeRecipient, oldFeeRecipient);
    }

    /// @notice Public function to return a list of accepted currencies
    function getListAcceptedCurrencies() public view returns (address[] memory) {
        return listAcceptedCurrencies;
    }

    /// @notice Called by contract owner to add a new accepted currency
    /// @param newCurrency Address of new currency
    function addAcceptedCurrency(address newCurrency) external onlyOwner {
        if (isCurrencyAccepted[newCurrency]) revert CurrencyAlreadyAccepted();
        if (newCurrency == address(0)) revert InvalidAddress();
        isCurrencyAccepted[newCurrency] = true;
        listAcceptedCurrencies.push(newCurrency);

        emit NewCurrencyAccepted(newCurrency);
    }

    /// @notice Called by contract owner to remove an accepted currency
    /// @param currencyToRemove Address of currency to remove
    function removeAcceptedCurrency(address currencyToRemove) external onlyOwner {
        if (!isCurrencyAccepted[currencyToRemove]) revert CurrencyNotAccepted();
        isCurrencyAccepted[currencyToRemove] = false;
        uint256 arrayLength = listAcceptedCurrencies.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            if (listAcceptedCurrencies[i] == currencyToRemove) {
                listAcceptedCurrencies[i] = listAcceptedCurrencies[arrayLength - 1];
                listAcceptedCurrencies.pop();
                break;
            }
        }

        emit CurrencyRemoved(currencyToRemove);
    }

    /// @notice Called by contract owner to add a new accepted collection
    /// @param newCollection Address of new collection
    function addAcceptedCollection(address newCollection) external onlyOwner {
        if (isCollectionAccepted[newCollection]) revert CollectionAlreadyAccepted();
        isCollectionAccepted[newCollection] = true;
        listAcceptedCollections.push(newCollection);

        emit NewCollectionAccepted(newCollection);
    }

    /// @notice Called by contract owner to remove an accepted collection
    /// @param collectionToRemove Address of collection to remove
    function removeAcceptedCollection(address collectionToRemove) external onlyOwner {
        if (!isCollectionAccepted[collectionToRemove]) revert CollectionNotAccepted();
        isCollectionAccepted[collectionToRemove] = false;
        uint256 arrayLength = listAcceptedCollections.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            if (listAcceptedCollections[i] == collectionToRemove) {
                listAcceptedCollections[i] = listAcceptedCollections[arrayLength - 1];
                listAcceptedCollections.pop();
                break;
            }
        }

        emit CollectionRemoved(collectionToRemove);
    }

    function _validateListing(Listing calldata listing) internal view {
        if (listing.order.currency == weth) {
            if (msg.value != listing.order.amount) revert PaymentMismatch();
        } else {
            if (IERC20(listing.order.currency).balanceOf(msg.sender) < listing.order.amount) revert PaymentMismatch();
        }

        if (IERC721(listing.order.collection).ownerOf(listing.order.tokenId) != listing.seller) revert SellerNotOwner();

        if (
            isUserNonceExecutedOrCancelled[listing.seller][listing.nonce]
                || listing.nonce <= userMinOrderNonce[listing.seller]
        ) {
            revert InvalidOrder();
        }

        if (block.timestamp > listing.order.expiry) revert OrderExpired();

        if (!SignatureAuthentication.verifyListingSignature(listing, domainSeparator)) revert SignatureInvalid();
    }

    function _validateOffer(Offer calldata offer) internal view {
        if (IERC20(offer.order.currency).balanceOf(offer.buyer) < offer.order.amount) revert PaymentMismatch();

        if (IERC721(offer.order.collection).ownerOf(offer.order.tokenId) != msg.sender) revert SellerNotOwner();

        if (isUserNonceExecutedOrCancelled[offer.buyer][offer.nonce] || offer.nonce <= userMinOrderNonce[offer.buyer]) {
            revert InvalidOrder();
        }

        if (block.timestamp > offer.order.expiry) revert OrderExpired();

        if (!SignatureAuthentication.verifyOfferSignature(offer, domainSeparator)) revert SignatureInvalid();
    }

    function _transferWalletForPayment(Order calldata order, address seller, address buyer, bool isETH) internal {
        uint256 marketplaceFeeAmount = _calculateMarketplaceFee(order.amount);

        if (isETH) {
            payable(marketplaceFeeRecipient).transfer(marketplaceFeeAmount);
            payable(seller).transfer(order.amount - marketplaceFeeAmount);
        } else {
            IERC20(order.currency).safeTransferFrom(buyer, marketplaceFeeRecipient, marketplaceFeeAmount);
            IERC20(order.currency).safeTransferFrom(buyer, seller, order.amount - marketplaceFeeAmount);
        }

        IERC721(order.collection).safeTransferFrom(seller, buyer, order.tokenId);
    }

    function _calculateMarketplaceFee(uint256 amount) internal returns (uint256) {
        return amount * marketplaceFee / precision;
    }
}
