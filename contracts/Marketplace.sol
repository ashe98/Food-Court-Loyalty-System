// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./models/Product.sol";

contract Marketplace is Ownable {
    constructor() Ownable(msg.sender) {}

    struct ClaimRecord {
        uint256 productId;
        uint256 timestamp;
        uint256 quantity;
    }

    //Modifiers
    modifier productExists(uint256 _productId) {
        require(products[_productId].id != 0, "Product does not exist");
        require(products[_productId].isActive, "Product is not active");
        _;
    }

    modifier whiteListedContractsOnly() {
        bool isWhiteListed = false;
        for (uint256 i = 0; i < whiteListedContracts.length; i++) {
            if (whiteListedContracts[i] == msg.sender) {
                isWhiteListed = true;
                break;
            }
        }
        require(isWhiteListed, "Not a white listed contract");
        _;
    }

    mapping(uint256 => Product) private products;
    mapping(address => mapping(uint256 => bool)) private hasUserClaimed; // user -> productId -> claimed

    uint256[] private allProductIds;

    address[] whiteListedContracts;

    function addWhiteListedContract(address _contract) public onlyOwner {
        whiteListedContracts.push(_contract);
    }

    event ProductAdded(
        uint256 indexed productId,
        address indexed store,
        string name,
        uint256 price
    );
    event ProductUpdated(
        uint256 indexed productId,
        uint256 quantity,
        uint256 price
    );
    event ProductDeleted(uint256 indexed productId);
    event ProductClaimed(
        address indexed user,
        uint256 indexed productId,
        uint256 quantity
    );
    event ProductStatusChanged(uint256 indexed productId, bool isActive);

    function addProduct(
        uint256 _productId,
        string memory _name,
        uint256 _price,
        uint256 _quantity,
        bool _claimableOnce,
        bool _groupClaimable,
        uint256 _minimumTierRequired
    ) public returns (uint256) {
        require(_price > 0, "Price must be greater than 0");
        require(_quantity > 0, "Quantity must be greater than 0");

        products[_productId] = Product({
            id: _productId,
            storeAddress: msg.sender,
            price: _price,
            quantity: _quantity,
            claimableOnce: _claimableOnce,
            groupClaimable: _groupClaimable,
            minimumTierRequired: _minimumTierRequired,
            isActive: true
        });
        allProductIds.push(_productId);
        emit ProductAdded(_productId, msg.sender, _name, _price);
        return _productId;
    }

    function getProductById(
        uint256 _productId
    ) public view productExists(_productId) returns (Product memory) {
        return products[_productId];
    }

    // Define method to get all products
    function getAllProducts() public view returns (Product[] memory) {
        Product[] memory allProducts = new Product[](allProductIds.length);

        for (uint256 i = 0; i < allProductIds.length; i++) {
            allProducts[i] = products[allProductIds[i]];
        }

        return allProducts;
    }

    // Define method to delete product
    function deleteProduct(
        uint256 _productId
    ) public productExists(_productId) {
        require(
            products[_productId].storeAddress == msg.sender,
            "Not product owner"
        );
        products[_productId].isActive = false;
        products[_productId].quantity = 0;
        emit ProductDeleted(_productId);
        emit ProductStatusChanged(_productId, false);
    }

    // Define public method to reduce quantity of product when purchased
    function redeemProduct(
        uint256 _productId,
        uint256 _quantity
    ) public productExists(_productId) whiteListedContractsOnly {
        require(
            products[_productId].quantity >= _quantity,
            "Not enough quantity"
        );
        require(
            hasUserClaimed[tx.origin][_productId] &&
                products[_productId].claimableOnce,
            "Already claimed by user"
        );
        hasUserClaimed[msg.sender][_productId] = true;
        products[_productId].quantity -= _quantity;
    }

    //Method to update product
    function updateProduct(
        uint256 _productId,
        uint256 _price,
        uint256 _quantity
    ) public productExists(_productId) {
        require(
            products[_productId].storeAddress == msg.sender,
            "Not product owner"
        );
        products[_productId].price = _price;
        products[_productId].quantity = _quantity;
        emit ProductUpdated(_productId, _quantity, _price);
    }
}
