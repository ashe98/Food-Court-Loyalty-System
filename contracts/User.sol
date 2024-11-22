// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Constants.sol";

import "./models/Tier.sol";

contract User is Ownable {
    constructor() Ownable() {}

    // Struct to store monthly transaction history for each user
    struct MonthlyTransactionHistory {
        uint256 totalTokensEarned;
        uint256 totalTransactions;
    }

    struct Customer {
        address customerAddress;
        Tier tier;
    }

    struct Store {
        address storeAddress;
    }

    address[] whiteListedContracts;

    ConstantsContract private constants;

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

    function addWhiteListedContract(address _contract) public onlyOwner {
        whiteListedContracts.push(_contract);
    }

    // Address of Constants Contract
    function updateConstantsContract(address newAddress) public onlyOwner {
        // Update the address of the Constants Contract
        // This function should only be called by the owner
        // The Constants Contract should be updated whenever the contract is deployed
        // to a new address
        constants = ConstantsContract(newAddress);
    }

    mapping(address => Customer) public customers;
    mapping(address => Store) public stores;
    mapping(address => MonthlyTransactionHistory)
        public monthlyTransactionHistory;

    //////////////////////////////////////////
    //
    // Events
    //
    //////////////////////////////////////////

    event CustomerRegistered(address customerAddress);
    event StoreRegistered(address storeAddress);
    event TransactionRecorded(
        address customerAddress,
        uint256 tokensEarned,
        uint256 totalTransactions
    );
    event TierUpdated(address customerAddress, Tier newTier);

    //////////////////////////////////////////

    //////////////////////////////////////////
    //
    // Public functions
    //
    //////////////////////////////////////////

    // Function to register new customer
    function registerCustomer(
        address customerAddress
    ) public whiteListedContractsOnly {
        require(
            customers[customerAddress].customerAddress == address(0),
            "Customer already registered"
        );
        Customer memory newCustomer = Customer({
            customerAddress: customerAddress,
            tier: Tier.Basic
        });
        customers[customerAddress] = newCustomer;
        emit CustomerRegistered(customerAddress);
    }

    //Function to register new store
    function registerStore(address store) public whiteListedContractsOnly {
        Store memory newStore = Store({storeAddress: store});
        stores[store] = newStore;
        emit StoreRegistered(store);
    }

    //Function to get customer details
    function getCustomer(
        address customerAddress
    ) public view returns (address, Tier) {
        require(
            customers[customerAddress].customerAddress != address(0),
            "Customer not found"
        );
        Customer memory customer = customers[customerAddress];
        return (customer.customerAddress, customer.tier);
    }

    // Function to check if a store exists
    function storeExists(address storeAddress) public view returns (bool) {
        return stores[storeAddress].storeAddress != address(0);
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

    //Function to update transaction history for user
    function recordTransaction(
        address customerAddress,
        uint256 tokensEarned
    ) public whiteListedContractsOnly {
        monthlyTransactionHistory[customerAddress]
            .totalTokensEarned += tokensEarned;
        monthlyTransactionHistory[customerAddress].totalTransactions += 1;
        emit TransactionRecorded(
            customerAddress,
            tokensEarned,
            monthlyTransactionHistory[customerAddress].totalTransactions
        );
    }

    // Function to be called by the Backend at the end of each month to revise the Tier of each user
    function calculateTierForUsers(
        address customerAddress
    ) public whiteListedContractsOnly {
        uint256 totalTokensEarned = monthlyTransactionHistory[customerAddress]
            .totalTokensEarned;
        uint256 totalTransactions = monthlyTransactionHistory[customerAddress]
            .totalTransactions;
        Tier currentTier = customers[customerAddress].tier;
        Tier newTier;

        // Downgrade tier if no tier is applicable
        if (currentTier == Tier.Basic) {
            newTier = Tier.Basic;
        } else {
            newTier = Tier(uint(currentTier) - 1);
        }

        if (
            currentTier == Tier.Basic &&
            totalTokensEarned >=
            constants.getIntegerConstant("BRONZE_REQ_TOKENS") &&
            totalTransactions >= constants.getIntegerConstant("BRONZE_REQ_TXNS")
        ) {
            newTier = Tier.Bronze;
        } else if (
            currentTier == Tier.Bronze &&
            totalTokensEarned >=
            constants.getIntegerConstant("SILVER_REQ_TOKENS") &&
            totalTransactions >= constants.getIntegerConstant("SILVER_REQ_TXNS")
        ) {
            newTier = Tier.Silver;
        } else if (
            currentTier >= Tier.Silver &&
            totalTokensEarned >=
            constants.getIntegerConstant("GOLD_REQ_TOKENS") &&
            totalTransactions >= constants.getIntegerConstant("GOLD_REQ_TXNS")
        ) {
            newTier = Tier.Gold;
        }

        customers[customerAddress].tier = newTier;
        delete monthlyTransactionHistory[customerAddress]; // reset transaction history
        emit TierUpdated(customerAddress, newTier);
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a >= b ? a : b;
    }
}
