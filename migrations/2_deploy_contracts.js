const User = artifacts.require("User");
const Constants = artifacts.require("ConstantsContract");
const Marketplace = artifacts.require("Marketplace");
const RewardToken = artifacts.require("RewardToken");

module.exports =  (deployer, network, accounts) => {
     deployer
     .deploy(Constants)
     .then(() => deployer.deploy(User))
     .then(() => deployer.deploy(Marketplace))
     .then(function () {
        return deployer.deploy(RewardToken, Marketplace.address, User.address);
     })
     ;
};
