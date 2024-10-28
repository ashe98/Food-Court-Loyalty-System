// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

contract User {

    struct Customer {
        uint256 id;
        address customerAddress;
        uint256 tier;
    }

    struct Store {
        uint256 id;
        address storeAddress;
    }
    
    mapping(address => Customer) public customers;

    mapping(address => Store) public stores;

}