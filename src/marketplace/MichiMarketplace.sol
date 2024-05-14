// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IMichiMarketplace.sol";
import "../libraries/SignatureAuthentication.sol";
import {Order, Listing, Offer} from "../libraries/OrderTypes.sol";

contract MichiMarketplace is IMichiMarketplace, Ownable {
    using SafeERC20 for IERC20;

    bytes32 public domainSeparator;

    address public immutable weth;

    address public marketplaceFeeRecipient;

    uint256 public marketplaceFee;

    uint256 public precision;

    mapping(address => uint256) public userMinOrderNonce;

    mapping(address => mapping(uint256 => bool)) public isUserNonceExecutedOrCancelled;

    mapping(address => bool) public isCurrencyAccepted;

    address[] public listAcceptedCurrencies;

    constructor(address weth_, uint256 marketplaceFee_, uint256 precision_) public {
        domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId, address verifyingContract)"),
                keccak256("MichiMarketplace"),
                keccak256(bytes("2")),
                block.chainid,
                address(this)
            )
        );
        weth = weth_;
        marketplaceFee = marketplaceFee_;
        precision = precision_;
    }

    function cancelAllOrdersForCaller(uint256 minNonce) external override {
        if (minNonce <= userMinOrderNonce[msg.sender]) revert NonceLowerThanCurrent();

        userMinOrderNonce[msg.sender] = minNonce;

        emit AllOrdersCancelled(msg.sender, minNonce);
    }

    function cancelOrdersForCaller(uint256[] calldata orderNonces) external override {
        if (orderNonces.length == 0) revert ArrayEmpty();

        for (uint256 i = 0; i < orderNonces.length; i++) {
            if (orderNonces[i] <= userMinOrderNonce[msg.sender]) revert NonceLowerThanCurrent();
            if (isUserNonceExecutedOrCancelled[msg.sender][orderNonces[i]]) revert OrderAlreadyCancelled();
            isUserNonceExecutedOrCancelled[msg.sender][orderNonces[i]] = true;
        }

        emit OrdersCancelled(msg.sender, orderNonces);
    }

    function executeListingETH(Listing calldata listing) external payable override {
        if (!isCurrencyAccepted[listing.order.currency]) revert CurrencyNotAccepted();
        if (listing.order.currency != weth) revert CurrencyMismatch();
        if (msg.sender == listing.seller) revert OrderCreatorCannotExecute();

        _validateListing(listing);

        _transferWalletForPayment(listing.order, listing.seller, msg.sender, true);

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

    function executeListing(Listing calldata listing) external override {
        if (!isCurrencyAccepted[listing.order.currency]) revert CurrencyNotAccepted();
        if (msg.sender == listing.seller) revert OrderCreatorCannotExecute();

        _validateListing(listing);

        _transferWalletForPayment(listing.order, listing.seller, msg.sender, false);

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

    function acceptOffer(Offer calldata offer) external override {
        if (!isCurrencyAccepted[offer.order.currency]) revert CurrencyNotAccepted();
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

    function setMarketplaceFee(uint256 newFee) external onlyOwner {
        if (newFee > 1000) revert InvalidFee();

        emit NewMarketplaceFee(newFee);
    }

    function getListAcceptedCurrencies() public view returns (address[] memory) {
        return listAcceptedCurrencies;
    }

    function addAcceptedCurrency(address newCurrency) external onlyOwner {
        if (isCurrencyAccepted[newCurrency]) revert CurrencyAlreadyAccepted();
        isCurrencyAccepted[newCurrency] = true;
        listAcceptedCurrencies.push(newCurrency);

        emit NewCurrencyAccepted(newCurrency);
    }

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
