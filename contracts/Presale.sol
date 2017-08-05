pragma solidity ^0.4.2;


import "./Pausable.sol";
import "./PullPayment.sol";
import "./UmbrellaCoin.sol";

/*
  Presale Smart Contract for the UMC project
  This smart contract collects ETH, and in return emits UmbrellaCoin tokens to the backers
*/
contract Presale is Pausable, PullPayment {
    
    using SafeMath for uint;

  	struct Backer {
		uint weiReceived; // Amount of Ether given
		uint coinSent;
	}

	/*
	* Constants
	*/
	/* Number of UmbrellaCoins per Ether */
	uint public constant COIN_PER_ETHER = 600000000; // 600 UmbrellaCoins
	/* Minimum number of UmbrellaCoin to sell */
	uint public constant MIN_CAP = 100 ether;
	/* Maximum number of UmbrellaCoin to sell */
	uint public constant MAX_CAP_ETHER = 2000 ether;
	/* Minimum amount to invest */
	uint public constant MIN_INVEST_ETHER = 100 finney;

	/*Presale*/
	/* Maximum number of UmbrellaCoin to sell for Presale */
	uint public constant MAX_CAP_ETHER_PRESALE = 1000 ether;
	/* Presale period */
	uint private constant PRESALE_PERIOD = 30 days;

	/*Crowdsale*/
	/* Maximum number of UmbrellaCoin to sell for Presale */
	uint public constant MAX_CAP_ETHER_CROWDSALE = 100000 ether;
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
	/* Presale start time */
	uint public startTime;
	/* Presale start time */
	uint public endTime;
 	/* Is Presale still on going */
	bool public PresaleClosed;
 	/* Is Presale still on going */
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
	function Presale(address _umbrellaCoinAddress, address _to) {
		coin = UmbrellaCoin(_umbrellaCoinAddress);
		multisigEther = _to;
	}

	/* 
	 * The fallback function corresponds to a donation in ETH
	 */
	function() stopInEmergency respectTimeFrame payable {
		receiveETH(msg.sender);
	}

	/* 
	 * To call to start the Presale
	 */
	function start() onlyOwner {
		require (startTime == 0); // Presale was already started

		startTime = now ;            
		endTime =  startTime + PRESALE_PERIOD + CROWDSALE_PERIOD;    
	}

	/*
	 *	Receives a donation in Ether
	*/
	function receiveETH(address beneficiary) internal {
		require(msg.value >= MIN_INVEST_ETHER); // Don't accept funding under a predefined threshold
		
		uint coinToSend = bonus(msg.value.mul(COIN_PER_ETHER).div(1 ether)); // Compute the number of UmbrellaCoin to send
		
		require(etherReceived <= MAX_CAP_ETHER);

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
		require(!PresaleClosed && !CrowdSaleClosed);
		if(!PresaleClosed)
			return amount.add(amount.div(3));   // bonus 33.3%
		else
			return amount;   // No bonus if you are beyond the presale
	}

	/*	
	 * Finalize the CrowdSale, should be called after the refund period
	*/
	function finalizeCrowdSale() onlyOwner public {

		if (now < endTime) { // Cannot finalise before PRESALE_PERIOD or before selling all coins
			require(etherReceived >= MAX_CAP_ETHER_CROWDSALE);
		}

		if (etherReceived < MIN_CAP && now < endTime + 15 days) revert(); // If MIN_CAP is not reached donors have 15days to get refund before we can finalise

		require(multisigEther.send(this.balance)); // Move the remaining Ether to the multisig address
		
		uint remains = coin.balanceOf(this);
		if (remains > 0) { // Convert the rest of UmbrellaCoins to float
			require (coin.float(remains)) ;
		}
		CrowdSaleClosed = true;
	}

		/*	
	 * Finalize the Presale, should be called after the refund period
	*/
	function finalizePresale() onlyOwner public {

		if (now < endTime) { // Cannot finalise before PRESALE_PERIOD or before selling all coins
			require(etherReceived >= MAX_CAP_ETHER_PRESALE);
		}

		require(multisigEther.send(this.balance)); // Move the remaining Ether to the multisig address
		
		uint remains = coin.balanceOf(this);
		if (remains > 0) { // Convert the rest of UmbrellaCoins to float
			require (coin.float(remains)) ;
		}
		PresaleClosed = true;
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
