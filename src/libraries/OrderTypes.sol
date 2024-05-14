// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

bytes32 constant LISTING_ORDER_HASH = keccak256(
    "Listing(address seller,address collection,address currency,uint256 tokenId,uint256 amount, uint256 orderExpiry)"
);

bytes32 constant OFFER_ORDER_HASH = keccak256(
    "Offer(address buyer,address collection,address currency,uint256 tokenId,uint256 amount, uint256 orderExpiry)"
);

struct Order {
    address collection;
    address currency;
    uint256 tokenId;
    uint256 amount;
    uint256 expiry;
}

struct Listing {
    Order order;
    address seller;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 nonce;
}

struct Offer {
    Order order;
    address buyer;
    uint8 v;
    bytes32 r;
    bytes32 s;
    uint256 nonce;
}
