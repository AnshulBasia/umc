pragma solidity ^0.4.2;


import "./Pausable.sol";
import "./PullPayment.sol";
import "./UmbrellaCoin.sol";

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
	uint public constant price = 1666 szabo;
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
	uint public constant MIN_CAP_ETHER_CROWDSALE = 5000 ether;
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
		 if (msg.value < MIN_INVEST_ETHER || msg.value > MAX_INVEST_ETHER) revert();
		
		uint coinToSend = bonus(msg.value.div(price).mul(1000000)); // Compute the number of UmbrellaCoin to send
		
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

		uint remains = coin.balanceOf(this);
 		if (remains > 0) { // Burn the rest of UmbrellaCoins
 			if (!coin.burn(remains)) throw ;
 		}
		
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

	/**
	 * Transfer remains to owner in case if impossible to do min invest
	 */
	function getRemainCoins() onlyOwner public {
		var remains = MAX_CAP - coinSentToEther;

		require(remains > MIN_CAP);

		Backer backer = backers[owner];
		coin.transfer(owner, remains); // Transfer UmbrellaCoins right now 

		backer.coinSent = backer.coinSent.add(remains);

		coinSentToEther = coinSentToEther.add(remains);

		// Send events
		LogCoinsEmited(this ,remains);
		LogReceivedETH(owner, etherReceived); 
	}


	/* 
  	 * When MIN_CAP is not reach:
  	 * 1) backer call the "approve" function of the UmbrellaCoin token contract with the amount of all UmbrellaCoins they got in order to be refund
  	 * 2) backer call the "refund" function of the Crowdsale contract with the same amount of UmbrellaCoins
   	 * 3) backer call the "withdrawPayments" function of the Crowdsale contract to get a refund in ETH
   	 */
	function refund(uint _value) minCapNotReached public {
		
		if (_value != backers[msg.sender].coinSent) throw; // compare value from backer balance

		coin.transferFrom(msg.sender, address(this), _value); // get the token back to the crowdsale contract

		if (!coin.burn(_value)) throw ; // token sent for refund are burnt

		uint ETHToSend = backers[msg.sender].weiReceived;
		backers[msg.sender].weiReceived=0;

		if (ETHToSend > 0) {
			asyncSend(msg.sender, ETHToSend); // pull payment to get refund in ETH
		}
}

}
