const truffleAssert = require('truffle-assertions');
const User = artifacts.require("User");


contract('User', (accounts) => {
    let userInstance;
    const owner = accounts[0]; // Contract owner
    const customer1 = accounts[1]; // Customer account
    const store = accounts[2]; // Store account

    before(async () => {
        userInstance = await User.deployed();
    });

    it('Register a new customer with specified tier and balance', async () => {
        let tier = 0; // Silver
        let balance = 100;
 
        let result = await userInstance.registerCustomer(tier, balance, { from: customer1 });

        truffleAssert.eventEmitted(result, 'CustomerRegistered', (ev) => {
            return ev.customerAddress === customer1 && ev.tier.toString() === tier.toString();
        });
    
        let customerDetails = await userInstance.getCustomer(customer1);

        assert.strictEqual(customerDetails[0], customer1, "Customer address mismatch!");
        assert.strictEqual(customerDetails[1].toNumber(), tier, "Customer tier mismatch!");
        assert.strictEqual(customerDetails[2].toNumber(), balance, "Customer balance mismatch!");
    });
    
    
    it('Register a new store', async () => {
        let result = await userInstance.registerStore({ from: store });

        truffleAssert.eventEmitted(result, 'StoreRegistered', (ev) => {
            return ev.storeAddress === store;
        });

        let storeDetails = await userInstance.getStore(store);
        assert.strictEqual(storeDetails, store, "Store address mismatch");
    });

    it('Get tier of a customer', async () => {
        let tier = await userInstance.getUserTier(customer1);
        assert.strictEqual(tier.toNumber(), 0, "Customer tier should be Silver");
    });

    it('Update tier', async () => {
        let newTier = 1; // updating tier from Silver to Gold
        await userInstance.updateCustomerTier(customer1, newTier, { from: owner });

        let updatedTier = await userInstance.getUserTier(customer1);
        assert.strictEqual(updatedTier.toNumber(), newTier, "Customer tier should be updated to Gold");
    });

    it('Delete a customer', async () => {
        await userInstance.deleteCustomer(customer1, { from: owner });

        try {
            await userInstance.getCustomer(customer1);
            assert.fail("Expected error not received");
        } catch (error) {
            assert(error.message.includes("Customer not found"), "Expected 'Customer not found' error");
        }
    });

    it('Delete a store', async () => {
        await userInstance.deleteStore(store, { from: owner });

        try {
            await userInstance.getStore(store);
            assert.fail("Expected error not received");
        } catch (error) {
            assert(error.message.includes("Store not found"), "Expected 'Store not found' error");
        }
    });
});