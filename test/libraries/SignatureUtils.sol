// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SignatureUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    struct Listing {
        address seller;
        address collection;
        address currency;
        uint256 tokenId;
        uint256 amount;
        uint256 expiry;
        uint256 nonce;
    }

    struct Offer {
        address buyer;
        address collection;
        address currency;
        uint256 tokenId;
        uint256 amount;
        uint256 expiry;
        uint256 nonce;
    }

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    bytes32 constant LISTING_HASH = keccak256(
        "Listing(address seller,address collection,address currency,uint256 tokenId,uint256 amount,uint256 expiry,uint256 nonce)"
    );

    bytes32 constant OFFER_HASH = keccak256(
        "Offer(address buyer,address collection,address currency,uint256 tokenId,uint256 amount,uint256 expiry,uint256 nonce)"
    );

    function getListingHash(Listing memory listing) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                LISTING_HASH,
                listing.seller,
                listing.collection,
                listing.currency,
                listing.tokenId,
                listing.amount,
                listing.expiry,
                listing.nonce
            )
        );
    }

    function getOfferHash(Offer memory offer) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                OFFER_HASH,
                offer.buyer,
                offer.collection,
                offer.currency,
                offer.tokenId,
                offer.amount,
                offer.expiry,
                offer.nonce
            )
        );
    }

    function getTypedListingHash(Listing memory listing) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getListingHash(listing)));
    }

    function getTypedOfferHash(Offer memory offer) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getOfferHash(offer)));
    }
}
