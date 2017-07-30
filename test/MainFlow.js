var UmbrellaCoin = artifacts.require("./UmbrellaCoin.sol");
var Crowdsale = artifacts.require("./Crowdsale.sol");

var TOTAL_COINS = 100000000000000;
var CROWDSALE_CAP = 70000000000000;
var PERIOD_28_DAYS = 28*24*60*60;
var UMC_PER_ETHER = 600000000;
var SEND_ETHER =  TOTAL_COINS/ UMC_PER_ETHER;
var RECEIVE_UMC_AMOUNT = SEND_ETHER * UMC_PER_ETHER;

contract('MainFlow', function(accounts) {

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

  it("Send 70,000,000.000000 UmbrellaCoin to Crowdsale contract", function() {
    return UmbrellaCoin.deployed().then(function(coin) {
      return coin.transfer(Crowdsale.address, CROWDSALE_CAP, {from: owner}).then(function (txn) {
        return coin.balanceOf.call(Crowdsale.address);
      });
    }).then(function (balance) {
      console.log("Crowdsale balance: " + balance);
      assert.equal(balance.valueOf(), CROWDSALE_CAP, "70,000,000.000000 wasn't in the Crowdsale account");
    });
  });


  it("Start Crowdsale contract", function() {
    return Crowdsale.deployed().then(function(crowd) {

      return crowd.start({from: owner}).then(function() {
        console.log("Crowdsale started");
      });
    });
  });

  it("Buy 100,000,000 coins", function() {
    return Crowdsale.deployed().then(function(crowd) {

        var logCoinsEmitedEvent = crowd.LogCoinsEmited();
        logCoinsEmitedEvent.watch(function(err, result) {
          if (err) {
            console.log("Error event ", err);
            return;
          }
          console.log("LogCoinsEmited event = ",result.args.amount,result.args.from);
        }); 

        var logReceivedETH = crowd.LogReceivedETH();
        logReceivedETH.watch(function(err, result) {
          if (err) {
            console.log("Error event ", err);
            return;
          }
          console.log("LogReceivedETH event = ",result.args.addr,result.args.value);
        }); 

        return crowd.sendTransaction({from: buyer, to: crowd.address, value: web3.toWei(SEND_ETHER, "ether")}).then(function(txn) {
          return UmbrellaCoin.deployed().then(function(coin) {
            return coin.balanceOf.call(buyer);
          });
       })
     }).then(function(balance) {
        console.log("Buyer balance: ", balance.valueOf(), " UMC");
        assert.equal(balance.valueOf(), RECEIVE_UMC_AMOUNT, RECEIVE_UMC_AMOUNT + " wasn't in the first account");
     });
  });

  it("Try to reserve the payments {from: buyer}", function() {
    return UmbrellaCoin.deployed().then(function(coin) {
      return coin.balanceOf.call(buyer).then(function(balance) {
        return Crowdsale.deployed().then(function(crowd) {
          console.log('Buyer UMC: ' + balance.valueOf());
          return coin.approveAndCall(crowd.address, balance.valueOf(), {from: buyer}).then(function() {
            assert(false, "Supposed to throw but didn't.");
          })
        }).catch(function(error) {
          console.log("Throw happened. Test succeeded.");
        });
      });
    });
  });

  it("Try to buy two more coins {from: buyer}", function() {
    return Crowdsale.deployed().then(function(crowd) {
       return crowd.sendTransaction({from: buyer, to: crowd.address, value: web3.toWei(CROWDSALE_CAP/UMC_PER_ETHER+1, "ether")}).then(function(txn) {
          assert(false, "Supposed to throw but didn't.");
       })
     }).catch(function(error) {
        console.log("Throw happened. Test succeeded.");
     });
  });

  it("Buy 6,000 coins without bonus", function() {
    return Crowdsale.deployed().then(function(crowd) {
       return crowd.sendTransaction({from: buyer, to: crowd.address, value: web3.toWei(1, "ether")}).then(function(txn) {
          return UmbrellaCoin.deployed().then(function(coin) {
            return coin.balanceOf.call(buyer);
          });
       })
     }).then(function(balance) {
        console.log("Buyer balance: ", balance.valueOf(), " UMC");
        assert.equal(balance.valueOf(), UMC_PER_ETHER, UMC_PER_ETHER + " wasn't in the first account");
     });
  });

  it("Try to burn coins", function() {
    return UmbrellaCoin.deployed().then(function(coin) {
      return coin.balanceOf.call(buyer).then(function(balance) {
        console.log("Buyer balance: ", balance.valueOf(), " UMC");
        return coin.float(balance.valueOf()).then(function() {
          assert(false, "Supposed to throw but didn't.");
        });
      });
    }).catch(function(error) {
      console.log("Throw happened. Test succeeded.");
    });
  });

  it("Set end of crowdsale period", function() {
    web3.evm.increaseTime(PERIOD_28_DAYS);
  });


  it("Try to buy 10,000 more coins {from: buyer}", function() {
    return Crowdsale.deployed().then(function(crowd) {
       return crowd.sendTransaction({from: buyer, to: crowd.address, value: web3.toWei(1, "ether")}).then(function(txn) {
          assert(false, "Supposed to throw but didn't.");
       })
     }).catch(function(error) {
        console.log("Throw happened. Test succeeded.");
     });
  });

  it("Finalize crowdsale", function() {
    return Crowdsale.deployed().then(function(crowd) {
      return crowd.finalize({from: owner}).then(function() {
        console.log("Finalize");
      });
    });
  });

  it("Try to invoke backUmbrellaCoinOwner {from: buyer}", function() {
    return Crowdsale.deployed().then(function(crowd) {
      return crowd.backUmbrellaCoinOwner({from: buyer}).then(function() {
        assert(false, "Supposed to throw but didn't.");
      }).catch(function(error) {
        console.log("Throw happened. Test succeeded.");
      });
    });
  });

  it("Invoke backUmbrellaCoinOwner {from: Crowdsale contract}", function() {
    return Crowdsale.deployed().then(function(crowd) {
      return crowd.backUmbrellaCoinOwner().then(function() {
        return UmbrellaCoin.deployed().then(function(coin) {
          return coin.owner.call().then(function(coinOwner) {
            console.log("UmbrellaCoin owner was changed to: " + coinOwner);
            assert.equal(coinOwner, owner, "UmbrellaCoin owner address must be equal to Crowdsale owner address");
          })              
        })
      }).catch(function(error) {
        assert(false, "Throw happened, but wasn't expected.");
      });
    });
  });


  it("Invoke backUmbrellaCoinOwner one more time {from: Crowdsale contract}", function() {
    return Crowdsale.deployed().then(function(crowd) {
      return crowd.backUmbrellaCoinOwner().then(function() {
        assert(false, "Supposed to throw but didn't.");
      }).catch(function(error) {
        console.log("Throw happened. Test succeeded.");
      });
    });
  });



  it("Get wallet balance", function() {
     printBalance();
  });


  function rpc(method, arg) {
    var req = {
      jsonrpc: "2.0",
      method: method,
      id: new Date().getTime()
    };

    if (arg) req.params = arg;

    return new Promise((resolve, reject) => {
      web3.currentProvider.sendAsync(req, (err, result) => {
        if (err) return reject(err)
        if (result && result.error) {
          return reject(new Error("RPC Error: " + (result.error.message || result.error)))
        }
        resolve(result)
      });
    })
  }

  // Change block time using the rpc call "evm_increaseTime"
  web3.evm = web3.evm || {}
  web3.evm.increaseTime = function (time) {
    return rpc('evm_increaseTime', [time]);
  }

});
