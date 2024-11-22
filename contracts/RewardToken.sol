// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./models/Product.sol";
import "./models/Group.sol";

import "./Marketplace.sol";
import "./User.sol";
import "./Constants.sol";

contract RewardToken is ERC20, Ownable {
    constructor(
        address marketplaceAddress,
        address userAddress
    ) ERC20("RewardToken", "RT") Ownable() {
        marketplace = Marketplace(marketplaceAddress);
        user = User(userAddress);
    }

    // Struct to store how many tokens a customer has and when they expire
    struct TokenBatch {
        uint256 transactionId;
        uint256 amount;
        uint256 expiration;
    }

    mapping(address => TokenBatch[]) private tokenBatches;
    mapping(address => bool) private isStore;
    mapping(address => bool) private isCustomer;
    mapping(address => mapping(address => uint256))
        private userLastTransactionTimestampForStore;
    mapping(address => Group) private groups; // ongoing Group transactions, customer -> Group
    mapping(address => mapping(address => uint256))
        private customerStoreTransactionCounts; // customer -> store -> transactions at that store

    Marketplace private marketplace;
    User private user;
    ConstantsContract private constants;

    event StoreAdded(address indexed store);
    event CustomerAdded(address indexed customer);
    event TokensMinted(
        address indexed customer,
        uint256 amount,
        uint256 expiration
    );
    event TokensBurned(address indexed customer, uint256 amount);
    event GroupCreated(address indexed originator, uint256 timestamp);
    event GroupJoined(address indexed member, address indexed groupOriginator);
    event GroupDeleted(address indexed originator);
    event TransactionRecorded(
        address indexed customer,
        uint256 amount,
        uint256 transactionId,
        address indexed store
    );
    event GroupTransactionCompleted(
        address indexed groupOriginator,
        uint256 indexed productId,
        uint256 memberCount,
        uint256 totalAmount
    );
    //////////////////////////////////////////
    //
    // Modifiers
    //
    //////////////////////////////////////////

    modifier onlyRegisteredUsers() {
        require(
            isCustomer[_msgSender()] ||
                isStore[_msgSender()] ||
                _msgSender() == owner(),
            "Only registered users can perform this action"
        );
        _;
    }

    modifier onlyStores() {
        require(isStore[_msgSender()], "Only stores can perform this action");
        _;
    }

    modifier burnExpiredTokens() {
        address customer = _msgSender();
        if (!isCustomer[customer]) {
            // this modifier is only for customers
            _;
            return;
        }
        _burnExpiredTokens(customer);
        _;
    }

    //////////////////////////////////////////

    //////////////////////////////////////////
    //
    // ERC 20 functions
    //
    //////////////////////////////////////////

    // Override transfer function to allow transfers only from customers->stores and stores->owner
    function transfer(
        address to,
        uint256 amount
    ) public override onlyRegisteredUsers burnExpiredTokens returns (bool) {
        address sender = _msgSender();
        if (isCustomer[sender]) {
            require(
                isStore[to],
                "Tokens from customers can only be transferred to stores"
            );
        } else if (isStore[sender]) {
            require(
                to == owner(),
                "Tokens from stores can only be transferred to owner"
            );
        }

        super._transfer(_msgSender(), to, amount);
        return true;
    }

    // Override transferFrom function to allow transfers only from customers to stores
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override onlyRegisteredUsers burnExpiredTokens returns (bool) {
        if (isCustomer[from]) {
            require(
                isStore[to],
                "Tokens from customers can only be transferred to stores"
            );
        } else if (isStore[from]) {
            require(
                to == owner(),
                "Tokens from stores can only be transferred to owner"
            );
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

    // Address of Constants Contract
    function updateConstantsContract(address newAddress) public onlyOwner {
        // Update the address of the Constants Contract
        // This function should only be called by the owner
        // The Constants Contract should be updated whenever the contract is deployed
        // to a new address
        constants = ConstantsContract(newAddress);
    }

    // Allow owner transfers to anyone
    function ownerTransfer(
        address from,
        address to,
        uint256 amount
    ) public onlyOwner {
        _transfer(from, to, amount);
    }

    function addStore(address store) public {
        isStore[store] = true;
        user.registerStore(store);
        emit StoreAdded(store);
    }

    function addCustomer(address customer) public {
        isCustomer[customer] = true;
        user.registerCustomer(customer);
        emit CustomerAdded(customer);
    }

    // The backend(owner) should make necessary checks to verify the transaction before calling this function
    function recordTransaction(
        address customer,
        uint256 txnAmount,
        uint256 transactionId,
        address storeAddress
    ) public onlyOwner burnExpiredTokens {
        uint256 tokenExpiryMonths = constants.getIntegerConstant(
            "TOKEN_EXPIRY_MONTHS"
        );
        uint256 expiration = block.timestamp + tokenExpiryMonths * 4 weeks; // 6 months
        uint256 amount = calculateTokensToMint(txnAmount);

        customerStoreTransactionCounts[customer][storeAddress]++;
        if (
            customerStoreTransactionCounts[customer][storeAddress] ==
            constants.getIntegerConstant("TOKEN_BONUS_TXN_COUNT")
        ) {
            amount += constants.getIntegerConstant("TOKEN_BONUS_TOKEN_AMOUNT"); // Add a bonus of 20 tokens after 20 transactions at the same store
        }

        mintTokens(customer, amount, expiration, transactionId);
        userLastTransactionTimestampForStore[customer][storeAddress] = block
            .timestamp;
        user.recordTransaction(customer, storeAddress, amount);
        emit TransactionRecorded(customer, amount, transactionId, storeAddress);
    }

    // In Production, ChainLink should be used to get the exact time of the transaction
    function calculateTokensToMint(
        uint256 txnAmount
    ) public view returns (uint256) {
        uint256 hour = ((block.timestamp + 8 * 60 * 60) / 60 / 60) % 24; // Convert to SGT (UTC+8)
        uint256 tokensPerDollar;

        // Define peak hours in SGT
        bool isPeakHour = (hour >=
            constants.getIntegerConstant("PEAK_HR_START_1") &&
            hour < constants.getIntegerConstant("PEAK_HR_END_1")) ||
            (hour >= constants.getIntegerConstant("PEAK_HR_START_2") &&
                hour < constants.getIntegerConstant("PEAK_HR_END_2"));

        if (isPeakHour) {
            tokensPerDollar = constants.getIntegerConstant("PEAK_HR_TOKENS");
        } else {
            tokensPerDollar = constants.getIntegerConstant(
                "NON_PEAK_HR_TOKENS"
            );
        }

        return txnAmount * tokensPerDollar;
    }

    function redeemTokensForCustomer(
        uint256 productId,
        address store
    ) public burnExpiredTokens {
        Product memory productToRedeem = marketplace.getProductById(productId); // get Product details
        // user should have made a transaction in the last 30 days at that store before redeeming a product
        require(
            block.timestamp -
                userLastTransactionTimestampForStore[_msgSender()][store] <=
                constants.getIntegerConstant("MIN_DAYS_LAST_TXN") * 1 days
        );
        require(
            balanceOf(_msgSender()) >= productToRedeem.price,
            "Customer does not have enough tokens to redeem"
        );
        require(
            uint(user.getUserTier(_msgSender())) >=
                productToRedeem.minimumTierRequired,
            "Customer does not have the required tier to redeem this product"
        );
        marketplace.redeemProduct(productId, 1); // reduce product quantity
        transfer(store, productToRedeem.price);
        user.recordTokenRedemption(
            _msgSender(),
            store,
            productId,
            productToRedeem.price
        );
    }

    // Creates a new group for group purchases
    function createGroup() public burnExpiredTokens {
        address customer = _msgSender();
        require(
            isCustomer[customer],
            "Only customers can create a group transaction"
        );
        require(
            groups[customer].originator == address(0),
            "Customer already has an ongoing group transaction"
        );
        address[] memory members = new address[](1);
        members[0] = customer;
        groups[customer] = Group(customer, members, block.timestamp);
        emit GroupCreated(customer, block.timestamp);
    }

    function joinGroup(address groupOriginator) public burnExpiredTokens {
        address customer = _msgSender();
        require(
            isCustomer[customer],
            "Only customers can join a group transaction"
        );
        require(
            groups[groupOriginator].originator != address(0),
            "Group does not exist"
        );
        require(groups[groupOriginator].members.length < 5, "Group is full");
        for (uint256 i = 0; i < groups[groupOriginator].members.length; i++) {
            require(
                groups[groupOriginator].members[i] != customer,
                "Customer is already in the group"
            );
        }
        groups[groupOriginator].members.push(customer);
        emit GroupJoined(customer, groupOriginator);
    }

    function makeGroupTransaction(
        uint256 productId,
        address store
    ) public burnExpiredTokens {
        address customer = _msgSender();
        require(
            isCustomer[customer],
            "Only customers can initiate a group transaction"
        );
        require(
            groups[customer].originator != address(0),
            "Customer does not have an ongoing group transaction"
        );
        require(groups[customer].members.length > 1, "Group is empty");
        if (block.timestamp - groups[customer].createdAt > 30 minutes) {
            deleteGroup(customer); // Delete group if expired
            require(false, "Group transaction expired");
        }
        Product memory productToRedeem = marketplace.getProductById(productId);
        require(
            productToRedeem.groupClaimable,
            "Product is not group claimable"
        );
        require(
            uint(user.getUserTier(groups[customer].originator)) >=
                productToRedeem.minimumTierRequired,
            "Group originator does not have the required tier to redeem this product"
        );
        uint256 groupSize = groups[customer].members.length;
        uint256 baseAmount = productToRedeem.price / groupSize;
        uint256 remainder = productToRedeem.price % groupSize;

        for (uint256 i = 0; i < groupSize; i++) {
            address member = groups[customer].members[i];
            _burnExpiredTokens(member);
            uint256 amountToTransfer = baseAmount;
            if (i < remainder) {
                amountToTransfer += 1; // Distribute the remainder
            }
            require(
                balanceOf(member) >= amountToTransfer,
                "Customer does not have enough tokens to redeem"
            );
        }

        // Redeem product
        marketplace.redeemProduct(productId, 1);
        for (uint256 i = 0; i < groupSize; i++) {
            address member = groups[customer].members[i];
            uint256 amountToTransfer = baseAmount;
            if (i < remainder) {
                amountToTransfer += 1; // Distribute the remainder
            }
            super._transfer(member, store, amountToTransfer);
        }
        emit GroupTransactionCompleted(
            customer,
            productId,
            groupSize,
            productToRedeem.price
        );
        deleteGroup(customer);
    }

    // Function to be called by the backend to clear the transaction count for a customer at a store at the end of each month
    function clearCustomerTransactionStoreCount(
        address customer,
        address store
    ) public onlyOwner {
        delete customerStoreTransactionCounts[customer][store];
    }

    //////////////////////////////////////////
    //
    // Helper/Internal functions
    //
    //////////////////////////////////////////
    // Mints new tokens and adds them to customer's batch
    function mintTokens(
        address customer,
        uint256 amount,
        uint256 expiration,
        uint256 transactionId
    ) internal {
        tokenBatches[customer].push(
            TokenBatch(transactionId, amount, expiration)
        );
        _mint(customer, amount);
        emit TokensMinted(customer, amount, expiration);
    }

    function _burnExpiredTokens(address customer) internal {
        if (!isCustomer[customer]) {
            return;
        }

        uint256 expiredAmount = 0;
        TokenBatch[] storage customerBatches = tokenBatches[customer];

        // Collect indices of expired tokens
        for (uint256 i = 0; i < customerBatches.length; i++) {
            if (customerBatches[i].expiration < block.timestamp) {
                expiredAmount += customerBatches[i].amount;

                // Remove expired tokens by shifting elements
                customerBatches[i] = customerBatches[
                    customerBatches.length - 1
                ];
                customerBatches.pop();
                i--; // Adjust index after removal
            }
        }

        if (expiredAmount > 0) {
            _burn(customer, expiredAmount); // Burn the expired token amount
            emit TokensBurned(customer, expiredAmount);
        }
    }

    function deleteGroup(address customer) internal {
        groups[customer] = Group(address(0), new address[](0), 0);
        emit GroupDeleted(customer);
    }

    //////////////////////////////////////////
}
