
const Test721 = artifacts.require('Test721');
const Auction = artifacts.require('Auction');

module.exports = function (deployer) {

    deployer.deploy(Test721).then(function(instance) {
        return deployer.deploy(Auction);
    }).catch(function(error) {
        console.log(error);
    });
}