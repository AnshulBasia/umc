pragma solidity ^0.4.2;

library SafeMath {
  function mul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
  function div(uint a, uint b) internal returns (uint) {
    assert(b > 0);
    uint c = a / b;
    assert(a == b * c + a % b);
    return c;
  }
  function sub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }
  function add(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }
  function max64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a >= b ? a : b;
  }
  function min64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a < b ? a : b;
  }
  function max256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a >= b ? a : b;
  }
  function min256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a < b ? a : b;
  }
}

contract ERC20Basic {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);
  function transfer(address to, uint value);
  event Transfer(address indexed from, address indexed to, uint value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) constant returns (uint);
  function transferFrom(address from, address to, uint value);
  function approve(address spender, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}

contract BasicToken is ERC20Basic {
  
  using SafeMath for uint;
  
  mapping(address => uint) balances;
  
  /*
   * Fix for the ERC20 short address attack  
  */
  modifier onlyPayloadSize(uint size) {
     require(msg.data.length >= size + 4);
     _;
  }

  function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
  }

  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }
}

contract StandardToken is BasicToken, ERC20 {
  mapping (address => mapping (address => uint)) allowed;

  function transferFrom(address _from, address _to, uint _value) onlyPayloadSize(3 * 32) {
    var _allowance = allowed[_from][msg.sender];
    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // if (_value > _allowance) throw;
    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
  }

  function approve(address _spender, uint _value) {
    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) revert();
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
  }

  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }
}

contract PullPayment {

  using SafeMath for uint;
  
  mapping(address => uint) public payments;

  event LogRefundETH(address to, uint value);


  /**
  *  Store sent amount as credit to be pulled, called by payer 
  **/
  function asyncSend(address dest, uint amount) internal {
    payments[dest] = payments[dest].add(amount);
  }

  // withdraw accumulated balance, called by payee
  function withdrawPayments() {
    address payee = msg.sender;
    uint payment = payments[payee];
    
    require (payment > 0);
    require (this.balance >= payment);

    payments[payee] = 0;

    require (payee.send(payment));
    
    LogRefundETH(payee,payment);
  }
}

contract Ownable {
    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require (msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}

contract Pausable is Ownable {
  bool public stopped;

  modifier stopInEmergency {
    require(!stopped);
    _;
  }
  
  modifier onlyInEmergency {
    require(stopped);
    _;
  }

  // called by the owner on emergency, triggers stopped state
  function emergencyStop() external onlyOwner {
    stopped = true;
  }

  // called by the owner on end of emergency, returns to normal state
  function release() external onlyOwner onlyInEmergency {
    stopped = false;
  }

}

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

}

/*
  Crowdsale Smart Contract for the UMC project
  This smart contract collects ETH, and in return emits UmbrellaCoin tokens to the backers
*/
contract Crowdsale is Pausable, PullPayment {
    
    using SafeMath for uint;

  	struct Backer {
		uint weiReceived; // Amount of Ether given
		uint coinSent;
	}

	/*
	* Constants
	*/
	/* Minimum number of UmbrellaCoin to sell */
	uint public constant MIN_CAP = 3000000000000; // 3,000,000 UmbrellaCoins
	/* Maximum number of UmbrellaCoin to sell */
	uint public constant MAX_CAP = 70000000000000; // 70,000,000 UmbrellaCoins
	/* Number of UmbrellaCoins per Ether */
	uint public constant COIN_PER_ETHER = 600000000; // 600 UmbrellaCoins
	/* Minimum amount to invest */
	uint public constant MIN_INVEST_ETHER = 100 finney;
	/* Maximum amount to invest */
	uint public constant MAX_INVEST_ETHER = 3000 ether;

	/*Presale*/
	/* Maximum number of ether to raise for Presale */
	uint public constant MAX_CAP_ETHER_PRESALE = 1000 ether;
	/* Minimum number of ether to raise for Presale */
	uint public constant MIN_CAP_ETHER_PRESALE = 100 ether;
	/* Presale period */
	uint private constant PRESALE_PERIOD = 30 days;

	/*Crowdsale*/
	/* Maximum number of ether to raise for Crowdsale */
	uint public constant MAX_CAP_ETHER_CROWDSALE = 100000 ether;
	/* Minimum number of ether to raise for Crowdsale */
	uint public constant MIN_CAP_ETHER_CROWDSALE = 2000 ether;
	/* CrowdSale period */
	uint private constant CROWDSALE_PERIOD = 30 days;


	/*
	* Variables
	*/
	/* UmbrellaCoin contract reference */
	UmbrellaCoin public coin;
    /* Multisig contract that will receive the Ether */
	address public multisigEther;
	/* Number of Ether received */
	uint public etherReceived;
	/* Number of UmbrellaCoins sent to Ether contributors */
	uint public coinSentToEther;
	/* start time */
	uint public startTime;
	/* start time */
	uint public endTime;
 	/* Is Crowdsale still on going */
	bool public CrowdSaleClosed;

	/* Backers Ether indexed by their Ethereum address */
	mapping(address => Backer) public backers;


	/*
	* Modifiers
	*/
	modifier minCapNotReached() {
		require(now > endTime);
		require(coinSentToEther <= MIN_CAP);
		_;
	}

	modifier respectTimeFrame() {
		require ((now >= startTime) && (now <= endTime ));
		_;
	}

	/*
	 * Event
	*/
	event LogReceivedETH(address addr, uint value);
	event LogCoinsEmited(address indexed from, uint amount);

	/*
	 * Constructor
	*/
	function Crowdsale(address _umbrellaCoinAddress) {
		coin = UmbrellaCoin(_umbrellaCoinAddress);
		multisigEther = msg.sender;
		CrowdSaleClosed = false;
	}

	/* 
	 * The fallback function corresponds to a donation in ETH
	 */
	function() stopInEmergency respectTimeFrame payable {
		receiveETH(msg.sender);
	}

	/* 
	 * To call to start the Crowdsale
	 */
	function start() onlyOwner {
		require (startTime == 0); // Crowdsale was already started

		startTime = now ;            
		endTime =  startTime + PRESALE_PERIOD + CROWDSALE_PERIOD;    
	}

	/*
	 *	Receives a donation in Ether
	*/
	function receiveETH(address beneficiary) internal {
		require(msg.value >= MIN_INVEST_ETHER); // Don't accept funding under a predefined threshold
		
		uint coinToSend = bonus(msg.value.mul(COIN_PER_ETHER).div(1 ether)); // Compute the number of UmbrellaCoin to send
		
		require(etherReceived <= MAX_CAP_ETHER_CROWDSALE);

		Backer storage backer = backers[beneficiary];
		coin.transfer(beneficiary, coinToSend); // Transfer UmbrellaCoins right now 

		backer.coinSent = backer.coinSent.add(coinToSend);
		backer.weiReceived = backer.weiReceived.add(msg.value); // Update the total wei collected during the crowdfunding for this backer    

		etherReceived = etherReceived.add(msg.value); // Update the total wei collected during the crowdfunding
		coinSentToEther = coinSentToEther.add(coinToSend);

		// Send events
		LogCoinsEmited(msg.sender ,coinToSend);
		LogReceivedETH(beneficiary, etherReceived); 
	}
	

	/*
	 *Compute the UmbrellaCoin bonus according to the investment period
	 */
	function bonus(uint amount) internal constant returns (uint) {
		require(now >= startTime);
		require(now < endTime);
		require(!CrowdSaleClosed);
		if(etherReceived < MAX_CAP_ETHER_PRESALE)
			return amount.mul(2);   // bonus 100%
		else
			return amount;   // No bonus if you are beyond the presale
	}

	/*	
	 * Finalize the CrowdSale, should be called after the refund period
	*/
	function finalizeCrowdSale() onlyOwner public {

		require (now > endTime || etherReceived >= MAX_CAP_ETHER_CROWDSALE);

		if (etherReceived < MIN_CAP_ETHER_CROWDSALE && now < endTime + 15 days) revert(); // If MIN_CAP is not reached donors have 15days to get refund before we can finalise

		require(multisigEther.send(this.balance)); // Move the remaining Ether to the multisig address
		
		CrowdSaleClosed = true;
	}

	/*	
	* Failsafe drain
	*/
	function drain() onlyOwner {
		require (owner.send(this.balance));
	}

	/**
	 * Allow to change the team multisig address in the case of emergency.
	 */
	function setMultisig(address addr) onlyOwner public {
		require (addr != address(0)); //No Null address
		multisigEther = addr;
	}

	/**
	 * Manually back UmbrellaCoin owner address.
	 */
	function backUmbrellaCoinOwner() onlyOwner public {
		coin.transferOwnership(owner);
	}

}