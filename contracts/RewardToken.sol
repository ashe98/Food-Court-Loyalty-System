// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {

    constructor(address _owner) ERC20("RewardToken", "RT") Ownable(msg.sender) {}

    // Struct to store how many tokens a customer has and when they expire
    struct TokenBatch {
        uint256 transactionId;
        uint256 amount;
        uint256 expiration;
    }

    mapping(address => TokenBatch[]) private tokenBatches;
    mapping(address => bool) private isStore;
    mapping(address => bool) private isCustomer;

    //////////////////////////////////////////
    //
    // Modifiers
    //
    //////////////////////////////////////////

    modifier onlyRegisteredUsers() {
        require(isCustomer[_msgSender()] || isStore[_msgSender()] || _msgSender() == owner(), "Only registered users can perform this action");
        _;
    }

    modifier onlyStores() {
        require(isStore[_msgSender()], "Only stores can perform this action");
        _;
    }

    modifier burnExpiredTokens() {
        address customer = _msgSender();
        if (!isCustomer[customer]) { // this modifier is only for customers
            _;
            return;
        }
        uint256 length = tokenBatches[customer].length;
        uint256 expiredAmount = 0;
        uint256[] memory expiredIndexes = new uint256[](length);

        // first find expired token batches
        for (uint256 i = 0; i < length; i++) {
            if (tokenBatches[customer][i].expiration < block.timestamp) {
                expiredAmount += tokenBatches[customer][i].amount;
            }
            else {
                expiredIndexes[i] = 1;
            }
        }

        // update the token batches array for the customer
        if (expiredAmount > 0) {
            uint256 newLength = length - expiredAmount;
            TokenBatch[] memory newTokenBatches = new TokenBatch[](newLength);
            uint256 j = 0;
            for (uint256 i = 0; i < length; i++) {
                if (expiredIndexes[i] == 1) {
                    newTokenBatches[j] = tokenBatches[customer][i];
                    j++;
                }
            }
            tokenBatches[customer] = newTokenBatches;
            _burn(customer, expiredAmount); // burn the expired token amount
        }
        _;
    }

    //////////////////////////////////////////

    //////////////////////////////////////////
    //
    // ERC 20 functions
    //
    //////////////////////////////////////////

    // Override transfer function to allow transfers only from customers->stores and stores->owner
    function transfer(address to, uint256 amount) public virtual override burnExpiredTokens() onlyRegisteredUsers() returns(bool) {
        address sender = _msgSender();
        if (isCustomer[sender]) {
            require(isStore[to], "Tokens from customers can only be transferred to stores");
        } else if (isStore[sender]) {
            require(to == owner(), "Tokens from stores can only be transferred to owner");
        }
        
        super._transfer(_msgSender(), to, amount);
        return true;
    }


    // Override transferFrom function to allow transfers only from customers to stores
    function transferFrom(address from, address to, uint256 value) public virtual override burnExpiredTokens() onlyRegisteredUsers() returns (bool) {
        if (isCustomer[from]) {
            require(isStore[to], "Tokens from customers can only be transferred to stores");
        } else if (isStore[from]) {
            require(to == owner(), "Tokens from stores can only be transferred to owner");
        }
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    //////////////////////////////////////////

    //////////////////////////////////////////
    //
    // Public functions
    //
    //////////////////////////////////////////

    // Allow owner transfers to anyone
    function ownerTransfer(address from, address to, uint256 amount) public onlyOwner {
        _transfer(from, to, amount);
    }


    function addStore(address store) public {
        isStore[store] = true;
    }

    function addCustomer(address customer) public {
        isCustomer[customer] = true;
    }

    // The backend(owner) should make necessary checks to verify the transaction before calling this function
    // The backend should calculate the amount of tokens to be minted based on the transaction amount and time of day
    function recordTransaction(address customer, uint256 amount, uint256 transactionId) public onlyOwner() {
        uint256 expiration = block.timestamp + 4 * 6 weeks; // 6 months
        mintTokens(customer, amount, expiration, transactionId);
    }

    //////////////////////////////////////////
    //
    // Helper/Internal functions
    //
    //////////////////////////////////////////

    function mintTokens(address customer, uint256 amount, uint256 expiration, uint256 transactionId) internal {
        tokenBatches[customer].push(TokenBatch(transactionId, amount, expiration));
        _mint(customer, amount);
    }

    //////////////////////////////////////////

}