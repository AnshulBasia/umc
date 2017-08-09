pragma solidity ^0.4.2;

import "./Contribution.sol";
import "./UmbrellaCoin.sol";

/*
  Contribution Smart Contract for the UMC project
  This smart contract collects ETH, and in return emits UmbrellaCoin tokens to the backers
*/


contract Claims {
    
    using SafeMath for uint;

    enum State {Active, Paid, Rejected}
	/*
	* Constants
	*/
	
/* The associated benefit package which is tied to the claim*/
    Contribution private associatedBenefitsPackage;

/* Amount asked by the package owner for a particular claim */
    uint private claimAsk;

/* Date on which claim was filed */
    uint private createdDate;

/* Processing status of the claim */
    uint private claimState;

	/*
	* Variables
	*/
	

	/*
	 * Event
	*/
	event LogReceivedETH(address addr, uint value);
	event LogCoinsEmited(address indexed from, uint amount);

/*Helper Functions*/
    
  /* Actually paying out the creator of the claim */
    function PayoutClaim() public
    {
        /* Payout the amount */
        UmbrellaCoin coin;
        coin = UmbrellaCoin(associatedBenefitsPackage.GetAddress());
        coin.transfer(associatedBenefitsPackage.GetAddress(), claimAsk); // Transfer UmbrellaCoins right now

        /* Change the state to paid out */
        claimState = State.Paid;

        /* Adjust the remaining amount they can use towards future claims*/
        associatedBenefitsPackage.ChangeTotalAmountUsedTillDate(claimAsk);
    }


    /* Actions after a claim gets rejected */
    function RejectClaim() public
    {
        claimState = State.Rejected;
    }

	/*
	 * Constructor
	*/
    function Claims(Contribution package, uint askAmount)
    {
        require (askAmount <= package.MaxPayable()); // Ask amount should be within the policy payout limits

        require (package.IsActivePackage()); // Only process claims for active accounts

        require (now > package.CreatedDate()); // we want to ensure we're past the cooling period -- how to write 3 months?

        associatedBenefitsPackage = package;

        claimAsk = askAmount;

        createdDate = now;

        claimState = State.Active;
    }

}