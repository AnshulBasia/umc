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
	/* Minimum number of UmbrellaCoin to sell */
	uint public constant MIN_CAP = 0;
	/* Maximum number of UmbrellaCoin to sell */
	uint public constant MAX_CAP_ETHER = 5000 ether;
	/* Minimum amount to invest */
	uint public constant MIN_INVEST_ETHER = 100 finney;
	/* Presale period */
	uint private constant PRESALE_PERIOD = 30 days;
	/* Number of UmbrellaCoins per Ether */
	uint public constant COIN_PER_ETHER = 600000000; // 600 UmbrellaCoins


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
	/* Presale end time */
	uint public endTime;
 	/* Is Presale still on going */
	bool public PresaleClosed;

	/* Backers Ether indexed by their Ethereum address */
	mapping(address => Backer) public backers;


	/*
	* Modifiers
	*/
	modifier minCapNotReached() {
		if ((now < endTime) || coinSentToEther >= MIN_CAP ) throw;
		_;
	}

	modifier respectTimeFrame() {
		if ((now < startTime) || (now > endTime )) throw;
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
		if (startTime != 0) throw; // Presale was already started

		startTime = now ;            
		endTime =  now + PRESALE_PERIOD;    
	}

	/*
	 *	Receives a donation in Ether
	*/
	function receiveETH(address beneficiary) internal {
		if (msg.value < MIN_INVEST_ETHER) throw; // Don't accept funding under a predefined threshold
		
		uint coinToSend = bonus(msg.value.mul(COIN_PER_ETHER).div(1 ether)); // Compute the number of UmbrellaCoin to send
		if (etherReceived > MAX_CAP_ETHER) throw;	

		Backer backer = backers[beneficiary];
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
		return amount.add(amount.div(3));   // bonus 33.3%
	}

	/*	
	 * Finalize the Presale, should be called after the refund period
	*/
	function finalize() onlyOwner public {

		if (now < endTime) { // Cannot finalise before PRESALE_PERIOD or before selling all coins
			if (etherReceived == MAX_CAP_ETHER) {
			} else {
				throw;
			}
		}

		if (etherReceived < MIN_CAP && now < endTime + 15 days) throw; // If MIN_CAP is not reached donors have 15days to get refund before we can finalise

		if (!multisigEther.send(this.balance)) throw; // Move the remaining Ether to the multisig address
		
		uint remains = coin.balanceOf(this);
		if (remains > 0) { // Convert the rest of UmbrellaCoins to float
			if (!coin.float(remains)) throw ;
		}
		PresaleClosed = true;
	}

	/*	
	* Failsafe drain
	*/
	function drain() onlyOwner {
		if (!owner.send(this.balance)) throw;
	}

	/**
	 * Allow to change the team multisig address in the case of emergency.
	 */
	function setMultisig(address addr) onlyOwner public {
		if (addr == address(0)) throw;
		multisigEther = addr;
	}

	/**
	 * Manually back UmbrellaCoin owner address.
	 */
	function backUmbrellaCoinOwner() onlyOwner public {
		coin.transferOwnership(owner);
	}

}
