pragma solidity ^0.4.2;


import "./Pausable.sol";
import "./PullPayment.sol";
import "./UmbrellaCoin.sol";

/*
  Contribution Smart Contract for the UMC project
  This smart contract collects ETH, and in return emits UmbrellaCoin tokens to the backers
*/

contract Contribution is Pausable, PullPayment {
    
    using SafeMath for uint;

	/*
	* Constants
	*/
	/* Minimum amount to invest */
	uint private constant MIN_CONTRIBUTE_ETHER = 100 finney;

    /* Max UmbrellaCoin cap of the Contribution*/
    uint private constant MAX_CONTRIBUTE_ETHER = 2000 finney; //2000 UmbrellaCoin

    /* Flat rate contribution multiplier*/
    uint private constant MAX_PAYOUT = 5; // 5x possible payout based on contrubution
	
    /* Number of UmbrellaCoins per Ether */
	uint public constant COIN_PER_ETHER = 600000000; // 600 UmbrellaCoins
    
    /* Percentage of total float acsessable for Contribution*/
    uint private constant PERCENTAGE_OF_FLOAT = 100; //1%

	/*
	* Variables
	*/
	/* Map a starttime to an Umnbrella coin amount */
	mapping(uint => uint) private contributionHistory;

	/*
	 * Event
	*/
	event LogReceivedETH(address addr, uint value);
	event LogCoinsEmited(address indexed from, uint amount);

/*Helper Functions*/
    
    /*Function to get current float*/
    function CurrentFloat() private returns (uint)
    {
        revert(); //TODO: need to get current float
    }

/*Function to convert finney to UmbrellaCoin*/
    function FinneyToUmbrella(uint amount) private returns (uint)
    {
        return amount.mul(COIN_PER_ETHER).div(1 ether);
    }

	/*
	 * Constructor
	*/
    function Contribution(/*address _umbrellaCoinAddress,*/ uint contributionAmount)
    {
        require (contributionAmount >= MIN_CONTRIBUTE_ETHER); // Don't accept too small of a policy

        require (contributionAmount <= MAX_CONTRIBUTE_ETHER); //Don't aceept too large a policy

        require (contributionAmount <= CurrentFloat().div(PERCENTAGE_OF_FLOAT)); //Don't accept to large a policy

        //TODO: Any other security checks here

        contributionHistory[now] = FinneyToUmbrella(contributionAmount);
    }

}