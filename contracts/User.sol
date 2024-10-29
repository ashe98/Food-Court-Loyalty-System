// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

contract User {

    enum Tier { Silver, Gold, Diamond } 

    struct Customer {
        address customerAddress;
        Tier tier;
        uint256 balance;
        mapping(uint256 => uint256) tokenExpiry; 
    }

    struct Store {
        address storeAddress;
    }
    
    mapping(address => Customer) public customers;

    mapping(address => Store) public stores;

    event CustomerRegistered(address customerAddress, uint256 tier);
    event StoreRegistered(address storeAddress);
    event TokenCredited(address customerAddress, uint256 amt);
    event TokensDeducted(address customerAddress, uint256 amt);

    uint256 public peakHourRate = 0.05 ether;
    uint256 public nonPeakHourRate = 0.1 ether;
    uint256 public tokenExpiryDuration = 180 days; //6months

    // Function to register new customer 
    function registerCustomer(Tier _tier) external {
        Customer storage newCustomer = customers[msg.sender];
        newCustomer.customerAddress = msg.sender;
        newCustomer.tier = _tier;
        newCustomer.balance = 0;
        emit CustomerRegistered(msg.sender,uint256(_tier));
    }

    //Function to register new store
    function registerStore() external {
        Store memory newStore = Store({
            storeAddress: msg.sender
        });
        stores[msg.sender] = newStore;
        emit StoreRegistered(msg.sender);
    }

    //Function to return the tier of user
    function getUserTier(address customerAddress) public view returns (Tier) {
      return customers[customerAddress].tier;
    }

    //Function that returns current balance of the user
    function viewBalance(address customerAddress) public view returns(uint256){
       uint256 expiredTokens = calculateExpiredTokens(customerAddress);
       uint256 updatedBalance=customers[customerAddress].balance - expiredTokens;
       return updatedBalance;
    }

    function calculateTokens(uint256 purchaseAmount, bool isPeakHours) internal view returns (uint256) {
        if (isPeakHours) {
            return (purchaseAmount * peakHourRate) / 1 ether;
        } else {
            return (purchaseAmount * nonPeakHourRate) / 1 ether;
        }
    }

    //Function that credits token to user account
     function creditToken(address customerAddress, uint256 purchaseAmount, bool isPeakHours) external {
        uint256 tokens= calculateTokens(purchaseAmount, isPeakHours);
        customers[customerAddress].balance += tokens;
        customers[customerAddress].tokenExpiry[block.timestamp + tokenExpiryDuration] += tokens;      
        emit TokenCredited(customerAddress, tokens);
    }

    //Function to calculate expired Tokens for a user
    function calculateExpiredTokens(address customerAddress) public view returns (uint256) {
        uint256 expiredTokens = 0;
        uint256 currentTime = block.timestamp;

        for (uint256 expiryTime in customer.tokenExpiry) {
            if (expiryTime <= currentTime) {
                expiredTokens += customers[customerAddress].tokenExpiry[expiryTime];
            }
        }
        return expiredTokens;
    }

    //Function to check user has sufficient token balance for a transaction
    function hasSufficientBalance(address customerAddress, uint256 amount) public view returns (bool) {
        return viewBalance(customerAddress) >= amount;
    }

    //Function to deducts tokens from a user's balance
    function deductTokens(address customerAddress, uint256 tokens) external {
        require(hasSufficientBalance(customerAddress, tokens), "Insufficient token balance");
        customers[customerAddress].balance -= tokens;
        emit TokensDeducted(customerAddress, tokens);
    }

}


    
