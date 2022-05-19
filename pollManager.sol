import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


// File: contracts/pollManager.sol


pragma solidity ^0.8.7;


// contract to launch polls and pay voters rewards in RXG

contract PollManager {
    // variables
    ERC20 rxgToken;
    uint256 reward;
    uint256 fee;
    uint256 totalPolls;
    uint256 pID;
    uint256[] pollIDs;
    // mappings
    //mapping(address => Poll) public creatorToPoll;
    mapping(uint256 => Poll) public pollIDtoPoll;
    //mapping(uint256 => address) public pollIDToCreator;

    // events
    event PollCreated(uint256 _pollID, uint256 duration, uint256 options);
    event PollClosed(uint256 _pollID, uint256 _winner);
    event Voted(address _voter, uint256 _pollID);
    event PollRewardPaid(uint256 _pollID, uint256 indexed amount);
    event PollPaidFor(uint256 _pollID, uint256 indexed amount);

    // contsructor
    constructor(
        address _RXGtokenAddress,
        uint256 _reward,
        uint256 _fee
    ) {
        require(_RXGtokenAddress!=address(0), "Address not specified");
        rxgToken = ERC20(_RXGtokenAddress);
        reward = _reward;
        fee = _fee;
        pID = 0;
    }

    // functions
    // launches a new poll contract for the user
    function createPoll(uint256 _duration, uint256 _options, string memory _ipfs)
        external
        returns (Poll)
    {
        require(_options > 1, "Poll must have at least two options");
        require(_options <= 10, "no more than 10 options");
        require(_duration > 0); // in seconds
        require(
            rxgToken.balanceOf(msg.sender) >= 100,
            "You need at least 100 RXG to create a poll"
        );
        require(
            rxgToken.transferFrom(msg.sender, address(this), 100 ether),
            "Failed to transfer RXG fee"
        );
        pID++;
        Poll _poll = new Poll( msg.sender, _duration, _options,  address(this), _ipfs);  
        pollIDtoPoll[pID] = _poll;
        //creatorToPoll[msg.sender] = _poll;
        //pollIDToCreator[pID] = msg.sender;
        setPollID(pID);
        emit PollCreated( pID,_duration, _options);
        return _poll;
    }

    // sends a users vote to the poll contract
    function vote(uint256 _pollID, uint256 _option) external {
        require(pollIDtoPoll[_pollID].isActive(), "Poll has ended");
        require(
            pollIDtoPoll[_pollID].hasVoted(msg.sender) == false,
            "You have already voted"
        );
        require(
            pollIDtoPoll[_pollID].vote(msg.sender, _option),
            "vote failed"
        );
        require(
            rxgToken.transfer(msg.sender, reward),
            "Failed to transfer RXG"
        );
        emit Voted(msg.sender, _pollID);
    }

    // closes the poll contract and returns the winner
    function closePoll(uint256 _pollID) external returns (uint256) {
        require(
            pollIDtoPoll[_pollID].getCreator() == msg.sender,
            "You can only close your own poll"
        );
        uint256 winner = pollIDtoPoll[_pollID].getWinner();
        // remove the users poll allowing them to create a new one
        delete pollIDtoPoll[_pollID];
        emit PollClosed(_pollID, winner);
        totalPolls--;
        return (winner);
    }

    // gets the entire poll for a given users address
    function getPoll(uint256 _pollID) external view returns (Poll) {
        return pollIDtoPoll[_pollID];
    }

    // gets the total amount of polls
    function getTotalPolls() external view returns (uint256) {
        return totalPolls;
    }

    // set the first empty address[] spot to the address of the poll
    function setPollID(uint256 _pollID) internal {
        for (uint256 i = 0; i < pollIDs.length; i++) {
            if (pollIDs[i] == 0) {
                pollIDs[i] = _pollID;
            }
        }
        pollIDs.push(_pollID);
    }

    // get all the polls
    function getAllPolls() external view returns (Poll[] memory) {
        Poll[] memory _polls = new Poll[](pollIDs.length);
        for (uint256 i = 0; i < pollIDs.length; i++) {
            _polls[i] = pollIDtoPoll[pollIDs[i]];
        }
        return _polls;
    }

    // get all poll addresses
    function getAllPollAddresses() external view returns (address[] memory) {
        address[] memory _pollAddresses = new address[](pollIDs.length);
        for (uint256 i = 0; i < pollIDs.length; i++) {
            _pollAddresses[i] = pollIDtoPoll[pollIDs[i]].getAddress();
        }
        return _pollAddresses;
    }

    // get ipfs location of poll by id
    function getPollIPFS(uint256 _pollID) external view returns (string memory) {
        string memory _ipfs = pollIDtoPoll[_pollID].getIPFS();
        return _ipfs;
    }
}


// poll contract
contract Poll {
    // variables
    string IPFS_location; // store IPFS location of poll options
    address public pollAddress;
    address public creator;
    address public manager;
    uint256 public duration;
    uint256 public startTime;
    uint256 public totalVotes;
    uint256[] public options;
    address[] public voters; // for payout of token
    bool public active;
    // events
    event Payout(address indexed voter, uint256 amount);
    // modifiers
    modifier onlyManager() {
        require(msg.sender == manager, "Only manager can call this function");
        _;
    }
    // mappings
    mapping(address => uint256) public votes;
    mapping(address => bool) public hasVoted;

    // constructor
    constructor(
        address _creator,
        uint256 _duration,
        uint256 _options,
        address _manager,
        string  memory _IPFS_location
    ) {
        require(_manager == msg.sender, "Manager must be the sender");
        require(_creator != address(0), "The creator's address must be specified");
        require(bytes(_IPFS_location).length > 0, "IPFS location cannot be blank");
        require(_options > 0, "Must have at least one option");
        require(_options < 10, "Cannot have more than 10 options");
        creator = _creator; // user who created the poll
        manager = _manager; // sent from manager contract
        IPFS_location = _IPFS_location; // IPFS location of poll options
        duration = _duration; // in seconds
        startTime = block.timestamp;
        totalVotes = 0;
        options = new uint256[](_options);
        pollAddress = address(this);
        active = true;
    }

    // functions
    // vote function.
    function vote(address _voter, uint256 _option)
        external
        onlyManager
        returns (bool _success)
    {
        // selection 1 is options array position 0
        require(_voter != address(0), "Cannot vote with the null address");
        require(_option < options.length, "Option does not exist");
        require(_option >= 0, "Option does not exist");
        require(!hasVoted[_voter], "You have already voted");
        totalVotes++;
        options[_option]++;
        hasVoted[_voter] = true;
        voters.push(_voter);
        return (true);
    }

    // returns the winning option if the poll has ended
    function getWinner() external onlyManager returns (uint256) {
        require(
            block.timestamp >= startTime + duration,
            "The poll has not ended yet"
        );
        uint256 winner = 0;
        uint256 winningVotes = 0;
        for (uint256 i = 0; i < options.length; i++) {
            if (options[i] > winningVotes) {
                winner = i;
                winningVotes = options[i];
            }
        }
        // set active to false to prep for removal
        active = false;
        return winner;
    }

    // get ipfs location
    function getIPFS() external view returns (string memory) {
        return IPFS_location;
    }

    // function to check the running number of votes each option has
    function getCurrentVotes() external view returns (uint256[] memory) {
        uint256[] memory currentVotes = new uint256[](options.length);
        for (uint256 i = 0; i < options.length; i++) {
            currentVotes[i] = options[i];
        }
        return currentVotes;
    }

    // function to check if poll has ended
    function isActive() external view onlyManager returns (bool) {
        return active;
    }

    // returns all voters
    function getVoters() external view onlyManager returns (address[] memory) {
        return voters;
    }

    // returns the number of options
    function getOptions()
        external
        view
        onlyManager
        returns (uint256 _numOptions)
    {
        return options.length;
    }

    // returns the current total number of voters
    function getTotalVotes()
        external
        view
        onlyManager
        returns (uint256 _totalVotes)
    {
        return totalVotes;
    }

    // returns the address of the poll
    function getAddress()
        external
        view
        onlyManager
        returns (address _pollAddress)
    {
        return pollAddress;
    }

    // returns the creator of the poll
    function getCreator()
        external
        view
        onlyManager
        returns (address _creator)
    {
        return creator;
    }
}
