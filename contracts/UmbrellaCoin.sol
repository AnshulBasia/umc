pragma solidity ^0.4.11;

import "./StandardToken.sol";
import "./Ownable.sol";


/**
 *  UmbrellaCoin token contract. Implements
 */
contract UmbrellaCoin is StandardToken, Ownable {
  string public constant name = "UmbrellaCoin";
  string public constant symbol = "UMC";
  uint public constant decimals = 6;


  // Constructor
  function UmbrellaCoin() {
      totalSupply = 100000000000000;
      balances[msg.sender] = totalSupply; // Send all tokens to owner
  }

  /**
   *  Burn away the specified amount of UmbrellaCoin tokens
   */
  function burn(uint _value) onlyOwner returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    totalSupply = totalSupply.sub(_value);
    Transfer(msg.sender, 0x0, _value);
    return true;
  }
  
  bytes32 public currentChallenge;                         // The coin starts with a challenge
  uint public timeOfLastProof;                             // Variable to keep track of when rewards were given
  uint public difficulty = 10**32;                         // Difficulty starts reasonably low

  function proofOfWork(uint nonce){
    bytes8 n = bytes8(sha3(nonce, currentChallenge));    // Generate a random hash based on input
    if (n < bytes8(difficulty)) throw;                   // Check if it's under the difficulty

    uint timeSinceLastProof = (now - timeOfLastProof);  // Calculate time since last reward was given
    if (timeSinceLastProof <  5 seconds) throw;         // Rewards cannot be given too quickly
    balanceOf[msg.sender] += timeSinceLastProof / 60 seconds;  // The reward to the winner grows by the minute

    difficulty = difficulty * 10 minutes / timeSinceLastProof + 1;  // Adjusts the difficulty

    timeOfLastProof = now;                              // Reset the counter
    currentChallenge = sha3(nonce, currentChallenge, block.blockhash(block.number-1));  // Save a hash that will be used as the next proof
  }

}






