// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Marketplace {
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

    // TODO: store a mapping of address -> list of products claimed
    mapping(uint256 => Product) private products;
    mapping(address => mapping(uint256 => bool)) private hasUserClaimed; // user -> productId -> claimed
    mapping(address => ClaimRecord[]) private userClaimHistory;
    uint256[] private allProductIds;

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

    // TODO: Define method to add product
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

    // TODO: Define method to get product by id
    function getProductById(
        uint256 _productId
    ) public view productExists(_productId) returns (Product memory) {
        return products[_productId];
    }

    // TODO: Define method to get all products
    function getAllProducts() public view returns (Product[] memory) {
        Product[] memory allProducts = new Product[](allProductIds.length);

        for (uint256 i = 0; i < allProductIds.length; i++) {
            allProducts[i] = products[allProductIds[i]];
        }

        return allProducts;
    }

    // TODO: Define method to delete product
    function deleteProduct(
        uint256 _productId
    ) public productExists(_productId) {
        require(
            products[_productId].storeAddress == msg.sender,
            "Not product owner"
        );
        products[_productId].isActive = false;
        emit ProductDeleted(_productId);
        emit ProductStatusChanged(_productId, false);
    }

    // TODO: Define public method to reduce quantity of product when purchased
    function reduceProductQuantity(
        uint256 _productId,
        uint256 _quantity
    ) public productExists(_productId) {
        require(
            products[_productId].quantity >= _quantity,
            "Not enough quantity"
        );
        products[_productId].quantity -= _quantity;
    }

    //Method to get user claim history
    function getUserClaimHistory(
        address _user
    ) public view returns (ClaimRecord[] memory) {
        return userClaimHistory[_user];
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
