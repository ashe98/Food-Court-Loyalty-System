// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Product {
    uint256 id;
    address storeAddress;
    uint256 price;
    uint256 quantity;
    bool claimableOnce;
    bool groupClaimable;
    uint256 minimumTierRequired;
    bool isActive;
}
