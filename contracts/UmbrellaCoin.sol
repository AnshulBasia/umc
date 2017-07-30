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
  struct BenefitsPackage {
      uint initialDeposit;
      uint maxPayout;
      uint createdStamp;
      bool waitingPeriodReached;
      bool matureDateReached;
  }
  mapping (address => BenefitsPackage) public benefits;

  // Constructor
  function UmbrellaCoin() {
      totalSupply = 100000000000000;
      balances[msg.sender] = totalSupply; // Send all tokens to owner
  }

  /**
   *  Burn away the specified amount of UmbrellaCoin tokens
   */
  function float(uint _value) onlyOwner returns (bool) {
    if (_value < 1) throw; // don't allow invald values.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    totalSupply = totalSupply.sub(_value);
    Transfer(msg.sender, floatHolder, _value);
    return true;
  }

  // create BenefitsPackage
  function createBenefitsPackage(uint _value) onlyOwner {
    if (_value < 1 || _value > 4000) throw; // don't allow invald values.
    if (benefits[msg.sender].initialDeposit != 0) throw;
    benefits[msg.sender] = BenefitsPackage(_value, _value.mul(3), now, false, false);
  }

  // cancel BenefitsPackage
  function cancelBenefitsPackage() onlyOwner {
    if (benefits[msg.sender].initialDeposit == 0) throw;
    if (isMatureDateReached(benefits[msg.sender]))
    {
      Transfer(floatHolder, msg.sender, benefits[msg.sender].initialDeposit);
    }
    else
    {
      Transfer(floatHolder, msg.sender, benefits[msg.sender].initialDeposit - benefits[msg.sender].initialDeposit.div(10));
    }
  }

  function max(uint a, uint b) private returns (uint) {
    return a > b ? a : b;
  }

  function isMatureDateReached(BenefitsPackage bp) private returns (bool) {
    return bp.createdStamp + 365 days > now;
  }

  function isWaitingPeriodReached(BenefitsPackage bp) private returns (bool) {
    return bp.createdStamp + 90 days > now;
  }

}






