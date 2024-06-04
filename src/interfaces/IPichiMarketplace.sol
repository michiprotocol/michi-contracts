// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Listing, Offer} from "../libraries/OrderTypes.sol";

interface IPichiMarketplace {
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

    error InvalidValue();

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

    event NewMarketplaceFee(uint256 indexed newMarketplaceFee, uint256 indexed oldMarketplaceFee);

    event NewMarketplaceFeeRecipient(address indexed newFeeRecipient, address indexed oldFeeRecipient);

    event NewCurrencyAccepted(address indexed newCurrency);

    event CurrencyRemoved(address indexed removedCurrency);

    event NewCollectionAccepted(address indexed newCollection);

    event CollectionRemoved(address indexed removedCollection);

    function cancelAllOrdersForCaller(uint256 minNonce) external;

    function cancelOrdersForCaller(uint256[] calldata orderNonces) external;

    function executeListing(Listing calldata listing) external payable;

    function acceptOffer(Offer calldata offer) external;

    function setMarketplaceFee(uint256 newFee) external;

    function setMarketplaceFeeRecipient(address newFeeRecipient) external;
}
