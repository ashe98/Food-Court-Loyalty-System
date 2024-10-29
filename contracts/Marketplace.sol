// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

contract Marketplace {
    struct Product {
        uint256 id;
        string name;
        address storeAddress;
        uint256 price;
        uint256 quantity;
        bool claimableOnce;
        bool groupClaimable;
        bool isActive;
    }

    struct ClaimRecord {
    uint256 productId;
    uint256 timestamp;
    uint256 quantity;
    }
    // State variables
    uint256 private nextProductId = 1; 

    //Modifiers
    modifier productExists(uint256 _productId) {
        require(products[_productId].id != 0, "Product does not exist");
        require(products[_productId].isActive, "Product is not active");
    _;
    }

    // modifier onlyStore() {
    //reference to an instance of an external User contract, which is used to check if the store is registered by the user accessing the contract
    //     require(userContract.stores(msg.sender).storeAddress == msg.sender, "Not a registered store");//checkd if the store is registered
    //     _;
    // }



    // TODO: store a mapping of address -> list of products claimed
    mapping(uint256 => Product) private products;
    mapping(address => mapping(uint256 => bool)) private hasUserClaimed; // user -> productId -> claimed
    mapping(address => ClaimRecord[]) private userClaimHistory;

    event ProductAdded(uint256 indexed productId, address indexed store, string name, uint256 price);
    event ProductUpdated(uint256 indexed productId, uint256 quantity, uint256 price);
    event ProductDeleted(uint256 indexed productId);
    event ProductClaimed(address indexed user, uint256 indexed productId, uint256 quantity);
    event ProductStatusChanged(uint256 indexed productId, bool isActive);

    // TODO: Define method to add product
     function addProduct(
        string memory _name,
        uint256 _price,
        uint256 _quantity,
        bool _claimableOnce,
        bool _groupClaimable
    ) external returns (uint256) {
        require(_price > 0, "Price must be greater than 0");
        require(_quantity > 0, "Quantity must be greater than 0");
        uint256 productId = nextProductId++;
        
        products[productId] = Product({
            id: productId,
            name: _name,
            storeAddress: msg.sender,
            price: _price,
            quantity: _quantity,
            claimableOnce: _claimableOnce,
            groupClaimable: _groupClaimable,
            isActive: true
        });
        emit ProductAdded(productId, msg.sender, _name, _price);
        return productId;
    }

    // TODO: Define method to get product by id
    function getProductById(uint256 _productId) 
        external 
        view 
        productExists(_productId) 
        returns (Product memory) 
    {
        return products[_productId];
    }

    // TODO: Define method to get all products
    function getAllProducts() 
        external 
        view 
        returns (Product[] memory) 
    {
        // First, count the number of active products
        uint256 activeCount = 0;
        for (uint256 i = 1; i < nextProductId; i++) {
            if (products[i].isActive) {
                activeCount++;
            }
        }
        // Create an array of the activeCount size
        Product[] memory allProducts = new Product[](activeCount);
        // Fill the array with active products
        uint256 currentIndex = 0;
        for (uint256 i = 1; i < nextProductId; i++) {
            if (products[i].isActive) {
                allProducts[currentIndex] = products[i];
                currentIndex++;
            }
        }
        return allProducts;
    }

    // TODO: Define method to delete product
    function deleteProduct(uint256 _productId) 
        external
        productExists(_productId) 
    {
        require(products[_productId].storeAddress == msg.sender, "Not product owner");
        products[_productId].isActive = false;
        emit ProductDeleted(_productId);
        emit ProductStatusChanged(_productId, false);
    }

    // TODO: Define public method to reduce quantity of product when purchased
    function reduceProductQuantity(uint256 _productId, uint256 _quantity) 
        external 
        productExists(_productId) 
    {
        require(products[_productId].quantity >= _quantity, "Not enough quantity");
        products[_productId].quantity -= _quantity;
    }

    //Method to get user claim history
    function getUserClaimHistory(address _user) 
        external 
        view 
        returns (ClaimRecord[] memory) 
    {
        return userClaimHistory[_user];
    }

    //Methof to update product
    function updateProduct(
        uint256 _productId,
        uint256 _price,
        uint256 _quantity
    ) 
        external
        productExists(_productId) 
    {
        require(products[_productId].storeAddress == msg.sender, "Not product owner");
        products[_productId].price = _price;
        products[_productId].quantity = _quantity;
        emit ProductUpdated(_productId, _quantity, _price);
    }
}