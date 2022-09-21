//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC20.sol";

contract CrowdFund {
    event Launch(
        uint id,
        address indexed creator, //With this, we can find all campaigns created from the same creator
        uint goal,
        uint32 startAt,
        uint32 endAt
    );
    event Cancel(
        uint id //Campaign ID
    );
    event Pledge(
        uint indexed id, //Many users able to pledge same campaign
        address indexed caller, //Same caller can pledged many campaigns
        uint amount
    );
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint indexed id, address indexed caller, uint amount);

    struct Campaign{
        address creator; //Creator of this campaign
        uint goal; //Total amont of token we need
        uint pledged; //Holds total amount of tokens
        uint32 startAt; //Start date of the campaign
        uint32 endAt; //End date of the campaign
        bool claimed; //If we claimed the tokens or not
    }

    IERC20 public immutable token; //For security reasons, we will only use one token
    uint public count; //Every time we create a campaign, the count will increase
    mapping(uint => Campaign) public campaigns;
    mapping(uint => mapping(address => uint)) public pledgeAmount; //How much amount of token each user pledged

    constructor(address _token){ // To initialize state variables
        token = IERC20(_token);
    }

    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external{
        /*
        - _goal: How much we want to raise for our goal
        - _startAt: The time when the campaign start
        - _endAt: The time when the campaign end
        */
        require(_startAt >= block.timestamp, "This campaign's start date is not yet to come!");
        require(_endAt <= block.timestamp + 90 days, "This campaign is already finished!");
        require(_endAt >= _startAt, "There is a problem with this campaign!");

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0, 
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    } 

    function cancel(uint _id) external{//Cancel the campaign IF the campaign didn't start
        Campaign memory campaign = campaigns[_id];

        require(msg.sender == campaign.creator, "You are not the creator of this campaign >:(");
        require(block.timestamp < campaign.startAt, "This campaign has not started yet!");
        
        delete campaigns[_id];

        emit Cancel(_id);
    }

    function pledge(uint _id, uint _amount) external{ //Once the campaign starts, users can pledge
        //_amount: The amount of token users send
        Campaign storage campaign = campaigns[_id];

        require(block.timestamp >= campaign.startAt, "This campaign has not started yet!");
        require(campaign.endAt <= block.timestamp, "This campaign finished!");
        
        campaign.pledged += _amount;
        pledgeAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    function unpledge(uint _id, uint _amount) external{ //If they change their mind about the campaign
        Campaign storage campaign = campaigns[_id];

        require(block.timestamp >= campaign.startAt, "This campaign has not started yet!");
        require(campaign.endAt <= block.timestamp, "This campaign finished!");
        
        campaign.pledged -= _amount;
        pledgeAmount[_id][msg.sender] -= _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim(uint _id) external{ //If campaign is successful, claim tokens
        Campaign storage campaign = campaigns[_id];

        require(msg.sender == campaign.creator, "You are not the creator of this campaign!");
        require(campaign.endAt > block.timestamp, "This campaign is not finished yet!");
        require(campaign.pledged >= campaign.goal, "There is not enough pledge for this campaign!");
        require(!campaign.claimed, "You already claimed it!");

        campaign.claimed = true;
        token.transfer(msg.sender, campaign.pledged);

        emit Claim(_id);
    }

    function refund(uint _id) external{ //If campaign is a unsuccessful, users can get their tokens back by calling this function
        Campaign storage campaign = campaigns[_id];

        require(campaign.endAt > block.timestamp, "This campaign is not finished yet!");
        require(campaign.pledged < campaign.goal, "There is not enough pledge for this campaign!");

        uint bal = pledgeAmount[_id][msg.sender];
        pledgeAmount[_id][msg.sender] = 0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}