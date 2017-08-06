module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    live: {
      network_id: 1, // Ethereum public network
    // optional config values
    // host - defaults to "localhost"
    // port - defaults to 8545
    // gas
    // gasPrice
    //  from  
    },
    rinkeby: {
      network_id: 4,        // Official Ethereum test network
      host: "localhost",
      port: 8545,
      gas: 21000,
      from: "0x277423818E720A4F43Ad73F1C2fFFe2E649b64bE"             
    }
  }
};
