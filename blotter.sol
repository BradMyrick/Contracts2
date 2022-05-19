// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// contract to map addresses to twitter links for promotion
contract blotter is ReentrancyGuard {
    address[] users;
    address activator;
    IERC20 token;
    address owner;
    uint256 index;
    uint256 public cost;
    struct tweet {
        bool live;
        string link;
        uint256 timestamp;
    }
    struct article {
        bool live;
        string link;
        uint256 timestamp;
    }
    mapping(address => tweet) public tweets;
    mapping(address => article) public articles;
    event TweetPromoted(address user, string link, uint256 timestamp);
    event TweetDemoted(address user, string link, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can do this");
        _;
    }
    modifier isAlive() {
        require(tweets[msg.sender].live, "Promotion is not live");
        _;
    }

    constructor(uint256 _cost, IERC20 _token) {
        // in wei, cost to promote a users twitter link
        token = _token;
        owner = msg.sender;
        activator = msg.sender;
        cost = _cost;
        index = 0;
    }

    function promoteTweet(string memory _link) external returns (tweet memory) {
        // check if the user is already promoted if so replace the tweet.
        if (tweets[msg.sender].live) {
            killPromotion(msg.sender);
        }
        // must be approved by owner to transfer RXG
        require(
            token.transferFrom(msg.sender, activator, cost),
            "RXG failed to transfer"
        );
        address _addr = msg.sender;
        tweets[_addr].link = _link;
        tweets[_addr].timestamp = block.timestamp;
        tweets[_addr].live = true;
        users.push(_addr);
        tweet memory _tweet = tweets[_addr];
        emit TweetPromoted(_addr, _tweet.link, _tweet.timestamp);
        return _tweet;
    }

    function getTwitterLinks(address _addr) public view returns (tweet memory) {
        return tweets[_addr];
    }

    function getUsers() public view returns (address[] memory) {
        return users;
    }

    function getAllTweets() external view returns (tweet[] memory) {
        tweet[] memory _tweets = new tweet[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            if (tweets[users[i]].live) {
                _tweets[i] = tweets[users[i]];
            }
        }
        return _tweets;
    }

    function getCost() public view returns (uint256) {
        return cost;
    }

    function killPromotion(address _addr) public onlyOwner isAlive {
        tweets[_addr].live = false;
        // remove from users
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == _addr) {
                delete users[i];
            }
        }
    }

    function getActivator() public view returns (address) {
        return activator;
    }

    function setActivator(address _activator) external onlyOwner {
        activator = _activator;
    }

}