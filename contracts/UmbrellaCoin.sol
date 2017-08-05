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
  address public constant floatHolder = 0x1A3C91B9Dfa069f5da7f24001777B161f5e0Fe60;

  // Constructor
  function UmbrellaCoin() {
      totalSupply = 100000000000000;
      balances[msg.sender] = totalSupply; // Send all tokens to owner
  }

  /**
   *  Burn away the specified amount of UmbrellaCoin tokens
   */
  function float(uint _value) onlyOwner returns (bool) {
    require (_value >= 1); // don't allow invald values.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    totalSupply = totalSupply.sub(_value);
    Transfer(msg.sender, floatHolder, _value);
    return true;
  }

}






