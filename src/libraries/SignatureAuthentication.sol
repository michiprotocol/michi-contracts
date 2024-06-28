// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./OrderTypes.sol";

library SignatureAuthentication {
    function verifyListingSignature(Listing calldata listing, bytes32 domainSeparator) internal view returns (bool) {
        bytes32 listingHash = _hashListing(listing);
        return _verifySignature(listing.seller, domainSeparator, listingHash, listing.v, listing.r, listing.s);
    }

    function verifyOfferSignature(Offer calldata offer, bytes32 domainSeparator) internal view returns (bool) {
        bytes32 offerHash = _hashOffer(offer);
        return _verifySignature(offer.buyer, domainSeparator, offerHash, offer.v, offer.r, offer.s);
    }

    function _hashListing(Listing calldata listing) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                LISTING_ORDER_HASH,
                listing.seller,
                listing.order.collection,
                listing.order.currency,
                listing.order.tokenId,
                listing.order.amount,
                listing.order.expiry,
                listing.nonce
            )
        );
    }

    function _hashOffer(Offer calldata offer) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                OFFER_ORDER_HASH,
                offer.buyer,
                offer.order.collection,
                offer.order.currency,
                offer.order.tokenId,
                offer.order.amount,
                offer.order.expiry,
                offer.nonce
            )
        );
    }

    function _verifySignature(address signer, bytes32 domainSeparator, bytes32 orderHash, uint8 v, bytes32 r, bytes32 s)
        private
        pure
        returns (bool)
    {
        // \x19\x01 is the standardized encoding prefix
        // https://eips.ethereum.org/EIPS/eip-712#specification
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, orderHash));

        return ecrecover(digest, v, r, s) == signer;
    }
}
