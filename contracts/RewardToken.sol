// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./models/Product.sol";
import "./models/Group.sol";

import "./Marketplace.sol";

contract RewardToken is ERC20, Ownable {
    constructor(
        address marketplaceAddress
    ) ERC20("RewardToken", "RT") Ownable(msg.sender) {
        marketplace = Marketplace(marketplaceAddress);
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

    Marketplace private marketplace;

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
    }

    function addCustomer(address customer) public {
        isCustomer[customer] = true;
    }

    // The backend(owner) should make necessary checks to verify the transaction before calling this function
    // The backend should calculate the amount of tokens to be minted based on the transaction amount and time of day
    function recordTransaction(
        address customer,
        uint256 amount,
        uint256 transactionId,
        address storeAddress
    ) public onlyOwner burnExpiredTokens {
        uint256 expiration = block.timestamp + 4 * 6 weeks; // 6 months
        mintTokens(customer, amount, expiration, transactionId);
        userLastTransactionTimestampForStore[customer][storeAddress] = block
            .timestamp;
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
                30 days
        );
        require(
            balanceOf(_msgSender()) < productToRedeem.price,
            "Customer does not have enough tokens to redeem"
        );
        marketplace.redeemProduct(productId, 1); // reduce product quantity
        transfer(store, productToRedeem.price);
    }

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
        address[] memory members = new address[](5);
        members[0] = customer;
        groups[customer] = Group(customer, members, block.timestamp);
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
        if (block.timestamp - groups[customer].createdAt <= 30 minutes) {
            deleteGroup(customer); // Delete group if expired
            require(false, "Group transaction expired");
        }
        Product memory productToRedeem = marketplace.getProductById(productId);
        require(
            productToRedeem.groupClaimable,
            "Product is not group claimable"
        );
        uint256 groupSize = groups[customer].members.length;
        for (uint256 i = 0; i < groupSize; i++) {
            address member = groups[customer].members[i];
            _burnExpiredTokens(member);
            require(
                balanceOf(member) < productToRedeem.price / groupSize,
                "Customer does not have enough tokens to redeem"
            );
        }

        // Redeem product
        marketplace.redeemProduct(productId, 1);
        for (uint256 i = 0; i < groupSize; i++) {
            address member = groups[customer].members[i];
            transferFrom(member, store, productToRedeem.price / groupSize);
        }

        deleteGroup(customer);
    }

    //////////////////////////////////////////
    //
    // Helper/Internal functions
    //
    //////////////////////////////////////////

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
    }

    function _burnExpiredTokens(address customer) internal {
        if (!isCustomer[customer]) {
            return;
        }
        uint256 length = tokenBatches[customer].length;
        uint256 expiredAmount = 0;
        uint256[] memory expiredIndexes = new uint256[](length);

        // first find expired token batches
        for (uint256 i = 0; i < length; i++) {
            if (tokenBatches[customer][i].expiration < block.timestamp) {
                expiredAmount += tokenBatches[customer][i].amount;
            } else {
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
    }

    function deleteGroup(address customer) internal {
        groups[customer] = Group(address(0), new address[](0), 0);
    }

    //////////////////////////////////////////
}
