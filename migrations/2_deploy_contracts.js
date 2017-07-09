var SafeMath = artifacts.require("./SafeMath.sol");
var UmbrellaCoin = artifacts.require("./UmbrellaCoin.sol");
var Crowdsale = artifacts.require("./Crowdsale.sol");


module.exports = function(deployer) {

	var owner = web3.eth.accounts[0];
	var wallet = web3.eth.accounts[1];

	// var owner = '0x6f2010D0FBaf8B7Dbc13eE7252FF8594A2Be3C51';
	// var wallet = '0x532691886A05eDc95457BFd5aEDA9b65b5413c83';

	console.log("Owner address: " + owner);	
	console.log("Wallet address: " + wallet);	

	deployer.deploy(SafeMath, { from: owner });
	deployer.link(SafeMath, UmbrellaCoin);
	return deployer.deploy(UmbrellaCoin, { from: owner }).then(function() {
		console.log("UmbrellaCoin address: " + UmbrellaCoin.address);
		return deployer.deploy(Crowdsale, UmbrellaCoin.address, wallet, { from: owner }).then(function() {
			console.log("Crowdsale address: " + Crowdsale.address);
			return UmbrellaCoin.deployed().then(function(coin) {
				return coin.owner.call().then(function(owner) {
					console.log("UmbrellaCoin owner : " + owner);
					return coin.transferOwnership(Crowdsale.address, {from: owner}).then(function(txn) {
						console.log("UmbrellaCoin owner was changed: " + Crowdsale.address);		
					});
				})
			});
		});
	});
};