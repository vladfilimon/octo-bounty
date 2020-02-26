var OctoBounty = artifacts.require("./OctoBounty.sol");
require('dotenv').config();

module.exports = function(deployer) {
    // Deployer is the Truffle wrapper for deploying
    // contracts to the network

    deployer.deploy(OctoBounty, process.env.OCTOBOUNTY_ARG_REPOSITORY, process.env.OCTOBOUNTY_ARG_ISSUE);
}
