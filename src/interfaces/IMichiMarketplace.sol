// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Listing, Offer} from "../libraries/OrderTypes.sol";

interface IMichiMarketplace {
    error NonceLowerThanCurrent();

    error ArrayEmpty();

    error OrderAlreadyCancelled();

    error SellerNotOwner();

    error InvalidOrder();

    error OrderExpired();

    error CurrencyMismatch();

    error OrderCreatorCannotExecute();

    error PaymentMismatch();

    error SignatureInvalid();

    error CurrencyAlreadyAccepted();

    error CurrencyNotAccepted();

    error CollectionAlreadyAccepted();

    error CollectionNotAccepted();

    error InvalidFee();

    error InvalidAddress();

    event OrdersCancelled(address user, uint256[] orderNonces);

    event AllOrdersCancelled(address user, uint256 minNonce);

    event WalletPurchased(
        address indexed seller,
        address indexed buyer,
        address indexed collection,
        address currency,
        uint256 tokenId,
        uint256 amount,
        uint256 nonce
    );

    event NewMarketplaceFee(uint256 indexed newMarketplaceFee);

    event NewMarketplaceFeeRecipient(address indexed newFeeRecipient);

    event NewCurrencyAccepted(address indexed newCurrency);

    event NewCollectionAccepted(address indexed newCollection);

    function cancelAllOrdersForCaller(uint256 minNonce) external;

    function cancelOrdersForCaller(uint256[] calldata orderNonces) external;

    function executeListingETH(Listing calldata listing) external payable;

    function executeListing(Listing calldata listing) external;

    function acceptOffer(Offer calldata offer) external;

    function setMarketplaceFee(uint256 newFee) external;

    function setMarketplaceFeeRecipient(address newFeeRecipient) external;
}
