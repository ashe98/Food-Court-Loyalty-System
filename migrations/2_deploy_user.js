const User = artifacts.require("User");

module.exports = async (deployer, network, accounts) => {
    await deployer.deploy(User);
};
