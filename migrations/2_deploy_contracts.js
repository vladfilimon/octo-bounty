const OctoBounty = artifacts.require("OctoBounty");

module.exports = function(deployer) {
  deployer.deploy(OctoBounty, "vladfilimon/poloniex-market-spread", "9");
};
