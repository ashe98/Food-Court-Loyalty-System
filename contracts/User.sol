// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract User {
    enum Tier {
        Silver,
        Gold,
        Diamond
    }

    struct Customer {
        address customerAddress;
        Tier tier;
        uint256 balance;
    }

    struct Store {
        address storeAddress;
    }

    mapping(address => Customer) public customers;
    mapping(address => Store) public stores;

    event CustomerRegistered(address customerAddress, uint256 tier);
    event StoreRegistered(address storeAddress);

    // Function to register new customer
    function registerCustomer(Tier _tier, uint256 _balance) public {
        require(
            customers[msg.sender].customerAddress == address(0),
            "Customer already registered"
        );
        Customer memory newCustomer = Customer({
            customerAddress: msg.sender,
            tier: _tier,
            balance: _balance
        });
        customers[msg.sender] = newCustomer;
        emit CustomerRegistered(msg.sender, uint256(_tier));
    }

    //Function to register new store
    function registerStore() public {
        Store memory newStore = Store({storeAddress: msg.sender});
        stores[msg.sender] = newStore;
        emit StoreRegistered(msg.sender);
    }

    //Function to get customer details
    function getCustomer(
        address customerAddress
    ) public view returns (address, Tier, uint256) {
        require(
            customers[customerAddress].customerAddress != address(0),
            "Customer not found"
        );
        Customer memory customer = customers[customerAddress];
        return (customer.customerAddress, customer.tier, customer.balance);
    }

    //Function to get store details
    function getStore(address storeAddress) public view returns (address) {
        require(
            stores[storeAddress].storeAddress != address(0),
            "Store not found"
        );

        Store memory store = stores[storeAddress];
        return store.storeAddress;
    }

    //Function to return the tier of user
    function getUserTier(address customerAddress) public view returns (Tier) {
        return customers[customerAddress].tier;
    }

    //Function to update customer tier
    function updateCustomerTier(address customerAddress, Tier newTier) public {
        require(
            customers[customerAddress].customerAddress != address(0),
            "Customer not found"
        );
        customers[customerAddress].tier = newTier;
    }

    // Function to delete a customer
    function deleteCustomer(address customerAddress) public {
        require(
            customers[customerAddress].customerAddress != address(0),
            "Customer not found"
        );
        delete customers[customerAddress];
    }

    //Function to delete a store
    function deleteStore(address storeAddress) public {
        require(
            stores[storeAddress].storeAddress != address(0),
            "Store not found"
        );
        delete stores[storeAddress];
    }
}
