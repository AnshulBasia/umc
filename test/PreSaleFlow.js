var UmbrellaCoin = artifacts.require("./UmbrellaCoin.sol");
var Presale = artifacts.require("./Presale.sol");

var TOTAL_COINS = 100000000000000;
var PRESALE_CAP = 1600000000000;
var PERIOD_28_DAYS = 28*24*60*60;
var UMC_PER_ETHER = 600000000;
var SEND_ETHER =  TOTAL_COINS/ UMC_PER_ETHER;
var RECEIVE_UMC_AMOUNT = SEND_ETHER * UMC_PER_ETHER;

contract('PresaleFlow', function(accounts) {

  var eth = web3.eth;
  var owner = eth.accounts[0];
  var wallet = eth.accounts[1];
  var buyer = eth.accounts[2];

  function printBalance() {
    const ownerBalance = web3.eth.getBalance(owner);
    const walletBalance = web3.eth.getBalance(wallet);
    const buyerBalance = web3.eth.getBalance(buyer);

    console.log("Owner balance", web3.fromWei(ownerBalance, "ether").toString(), " ETHER");
    console.log("Wallet balance", web3.fromWei(walletBalance, "ether").toString(), " ETHER");
    console.log("Buyer balance", web3.fromWei(buyerBalance, "ether").toString(), " ETHER");
  }


    it("should put 100,000,000.000000 UmbrellaCoin in the owner account", function() {
    return UmbrellaCoin.deployed().then(function(instance) {
      return instance.balanceOf.call(owner);
    }).then(function(balance) {
      assert.equal(balance.valueOf(), TOTAL_COINS, "100,000,000.000000 wasn't in the owner account");
    });
  });

 it("Send 1,600.000000 UmbrellaCoin to Presale contract", function() {
    return UmbrellaCoin.deployed().then(function(coin) {
      return coin.transfer(Presale.address, PRESALE_CAP, {from: owner}).then(function (txn) {
        return coin.balanceOf.call(Presale.address);
      });
    }).then(function (balance) {
      console.log("Presale balance: " + balance);
      assert.equal(balance.valueOf(), PRESALE_CAP, "1,600,000.000000 wasn't in the Presale account");
    });
  });


  it("Start Presale contract", function() {
    return Presale.deployed().then(function(crowd) {

      return crowd.start({from: owner}).then(function() {
        console.log("Presale started");
      });
    });
  });
 });