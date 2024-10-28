// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

contract Marketplace {

    struct Product {
        uint256 id;
        uint256 price;
        uint256 quantity;
        bool claimableOnce;
        bool groupClaimable;
        uint256 minimumTierRequired;
    }

    // TODO: store a mapping of address -> list of products claimed

    // TODO: Define method to add product

    // TODO: Define method to get product by id

    // TODO: Define method to get all products

    // TODO: Define method to delete product

    // TODO: Define public method to reduce quantity of product when purchased

}