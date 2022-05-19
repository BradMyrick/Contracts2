// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract VotingBooth is Ownable{
// allow a creator to pay 100 rxg to start a poll
// the creator will give the poll a title and a description and a number of options
// the creator will provide a time in seconds for the poll to last
// a user will earn .05 rxg for voting on a poll and can only vote once per poll
    using SafeMath for uint256;

    IERC20 public token;
    // variables
    struct Poll{
        string title;
        string description;
        uint256 endTime;
        uint32 options;
        address creator;
    }

    struct Vote {
        uint32 option; 
    }

    // Access each poll by pollId
    mapping (uint => Poll) public polls;

    // Double mapping from user address => pollId => user's vote
    mapping (address => mapping (uint => Vote)) public votes;

    // Track number of polls to use as pollId's
    uint public pollCount;
    
    constructor(address _token) {
        require(_token != address(0), "The address of the contract is not specified.");
        token = IERC20(_token);
    }
    
    // functions
    function createPoll(string memory _title, string memory _description, uint32 _options, uint256 _endTime) public payable {
        require(token.balanceOf(msg.sender) >= 100, "You must pay 100 rxg to create a poll.");
        require(_options >= 1 && _options <= 5, "You can only have 5 options.");
        require(_endTime > block.timestamp);

        pollCount = pollCount.add(1);
        polls[pollCount].title = _title;
        polls[pollCount].description = _description;
        polls[pollCount].endTime = _endTime;
        polls[pollCount].options = _options;
        polls[pollCount].creator = msg.sender;

        token.transferFrom(msg.sender, address(this), 100 * (10 ** 18));
    }

    function vote(uint _pollId, uint32 _option ) public payable {

        require(polls[_pollId].endTime >= block.timestamp, "Voting is no longer active.");
        require(_option >= 1 && _option <= 5, "You can only have 5 options.");
        require(votes[msg.sender][_pollId].option !=0, "User has already voted.");

        Vote memory vote = Vote(_option);
        votes[msg.sender][_pollId] = vote;

        token.transfer(msg.sender, 5 * (10 ** 16));

    }
}
