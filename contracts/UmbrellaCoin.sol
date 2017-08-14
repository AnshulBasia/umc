pragma solidity ^0.4.2;

import "./StandardToken.sol";
import "./Ownable.sol";


/**
 *  UmbrellaCoin token contract.
 */
contract UmbrellaCoin is StandardToken, Ownable {
  string public constant name = "UmbrellaCoin";
  string public constant symbol = "UMC";
  uint public constant decimals = 6;
  address public floatHolder;

  // Constructor
  function UmbrellaCoin() {
      totalSupply = 100000000000000;
      balances[msg.sender] = totalSupply; // Send all tokens to owner
      floatHolder = msg.sender;
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

}






