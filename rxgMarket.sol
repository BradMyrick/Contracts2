// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract AuctionManager {
    uint _auctionIdCounter; // auction Id counter
    mapping(uint => Auction) public auctions; // auctions
    address public owner; // owner of the contract

// modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
// constructor
    constructor() {
        owner = msg.sender;
        _auctionIdCounter = 0;
    }
// functions
    // set owner
    function setOwner(address _owner) onlyOwner public {
        owner = _owner;
    }
    // create an auction
    function createAuction(uint _endTime, uint _minIncrement, uint _directBuyPrice,uint _startPrice,address _nftAddress,uint _tokenId) external returns (bool)
        {
            require(_nftAddress!=address(0), "Address not specified");
            IERC721 _nftToken = IERC721(_nftAddress); // get the nft token
            require(_nftToken.ownerOf(_tokenId) == msg.sender, "You are not the owner of this token");
            require(_directBuyPrice > 0); // direct buy price must be greater than 0
            require(_startPrice < _directBuyPrice); // start price is smaller than direct buy price
            require(_endTime > 59 minutes); // end time must at least one hour to allow for block confirmation

            uint auctionId = _auctionIdCounter; // get the current value of the counter
            _auctionIdCounter++; // increment the counter
            Auction auction = new Auction(msg.sender, _endTime, _minIncrement, _directBuyPrice, _startPrice, _nftAddress, _tokenId); // create the auction
            auctions[auctionId] = auction; // add the auction to the map
            return true;
        }

    // Return a list of all auctions
    function getAuctions() external view returns(address[] memory _auctions) 
        {
            _auctions = new address[](_auctionIdCounter); // create an array of size equal to the current value of the counter
            for(uint i = 0; i < _auctionIdCounter; i++) { // for each auction
                _auctions[i] = address(auctions[i]); // add the address of the auction to the array
            }
            return _auctions; // return the array
        }

    // Return the information of each auction address
    function getAuctionInfo(address[] calldata _auctionsList)
        external
        view
        returns (
            uint256[] memory directBuy,
            address[] memory creators,
            uint256[] memory highestBid,
            uint256[] memory tokenIds,
            uint256[] memory endTime,
            uint256[] memory startPrice,
            uint256[] memory auctionState
        )
        {
            directBuy = new uint256[](_auctionsList.length); // create an array of size equal to the length of the passed array
            creators = new address[](_auctionsList.length); // create an array of size equal to the length of the passed array
            highestBid = new uint256[](_auctionsList.length);
            tokenIds = new uint256[](_auctionsList.length);
            endTime = new uint256[](_auctionsList.length);
            startPrice = new uint256[](_auctionsList.length);
            auctionState = new uint256[](_auctionsList.length);


            for (uint256 i = 0; i < _auctionsList.length; i++) { // for each auction
                directBuy[i] = Auction(auctions[i]).directBuyPrice(); // get the direct buy price
                creators[i] = Auction(auctions[i]).creator(); // get the owner of the auction
                highestBid[i] = Auction(auctions[i]).maxBid(); // get the highest bid
                tokenIds[i] = Auction(auctions[i]).tokenId(); // get the token id
                endTime[i] = Auction(auctions[i]).endTime(); // get the end time
                startPrice[i] = Auction(auctions[i]).startPrice(); // get the start price
                auctionState[i] = uint(Auction(auctions[i]).getAuctionState()); // get the auction state
            }
            
            return ( // return the arrays
                directBuy,
                creators,
                highestBid,
                tokenIds,
                endTime,
                startPrice,
                auctionState
            );
        }

    // complete auction purchase
    function completePurchase(address _auctionAddress) external returns (bool)
        {
            require(Auction(_auctionAddress).getCreator() == msg.sender || owner == msg.sender); // only the creator or the owner can complete the purchase
            Auction(_auctionAddress).completePurchase(); // complete the purchase
            return true;
        }
    // cancel auction
    function cancelAuction(address _auctionAddress) external returns (bool)
        {
            require(Auction(_auctionAddress).getCreator() == msg.sender || owner == msg.sender); // only the creator or the owner can cancel the auction
            Auction(_auctionAddress).cancelAuction(); // cancel the auction
            return true;
        }
}

// Auction contract

contract Auction {
// variables
    using SafeMath for uint256;
    address public manager;
    uint256 public endTime; // Timestamp of the end of the auction (in seconds)
    uint256 public startTime; // The block timestamp which marks the start of the auction
    uint public maxBid; // The maximum bid
    address public maxBidder; // The address of the maximum bidder
    address public creator; // The address of the auction creator
    Bid[] public bids; // The bids made by the bidders
    uint public tokenId; // The id of the token
    bool public isCancelled; // If the the auction is cancelled
    bool public boughtNow; // True if the auction ended due to direct buy
    uint public minIncrement; // The minimum increment for the bid  
    uint public directBuyPrice; // The price for a direct buy
    uint public startPrice; // The starting price for the auction
    address public nftAddress;  // The address of the NFT contract
    IERC721 nft; // The NFT token

    enum AuctionState { 
        OPEN,
        CANCELLED,
        ENDED,
        DIRECT_BUY
    }

    struct Bid { // A bid on an auction
        address sender;
        uint256 bid;
    }
// modifiers
    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }
// events
    event NewBid(address bidder, uint bid); // A new bid was placed
    event WithdrawToken(address withdrawer); // The auction winner withdrawed the token
    event WithdrawFunds(address withdrawer, uint256 amount); // The auction owner withdrew the funds
    event AuctionCanceled(); // The auction was cancelled
// constructor
    constructor(address _creator,uint _endTime,uint _minIncrement,uint _directBuyPrice, uint _startPrice,address _nftAddress,uint _tokenId)
        {
            require(_nftAddress!=address(0), "Address not specified");
            manager = msg.sender;
            creator = _creator; // The address of the auction creator
            endTime = block.timestamp +  _endTime; // The timestamp which marks the end of the auction (now + 30 days = 30 days from now)
            startTime = block.timestamp; // The timestamp which marks the start of the auction
            minIncrement = _minIncrement; // The minimum increment for the bid
            directBuyPrice = _directBuyPrice; // The price for a direct buy
            startPrice = _startPrice; // The starting price for the auction
            nft = IERC721(_nftAddress); // The address of the nft token
            nftAddress = _nftAddress;
            tokenId = _tokenId; // The id of the token
            maxBidder = _creator; // Setting the maxBidder to auction creator.
        }

// functions

    // Returns a list of all bids and addresses
    function allBids()
        external
        view
        returns (address[] memory, uint256[] memory)
        {
            address[] memory addrs = new address[](bids.length);
            uint256[] memory bidPrice = new uint256[](bids.length);
            for (uint256 i = 0; i < bids.length; i++) {
                addrs[i] = bids[i].sender;
                bidPrice[i] = bids[i].bid;
            }
            return (addrs, bidPrice);
        }

    // Place a bid on the auction
    function placeBid() payable external returns(bool)
        {
            require(msg.sender != creator); // The auction creator can not place a bid
            require(getAuctionState() == AuctionState.OPEN); // The auction must be open
            require(msg.value > startPrice); // The bid must be higher than the starting price
            require(msg.value > maxBid + minIncrement); // The bid must be higher than the current bid + the minimum increment

            address lastHightestBidder = maxBidder; // The address of the last highest bidder
            uint256 lastHighestBid = maxBid; // The last highest bid
            maxBid = msg.value; // The new highest bid
            maxBidder = msg.sender; // The address of the new highest bidder
            if(msg.value >= directBuyPrice){ // If the bid is higher than the direct buy price
                boughtNow = true; // The auction has ended
                completePurchase(); // Complete the purchase
            }
            bids.push(Bid(msg.sender,msg.value)); // Add the new bid to the list of bids

            if(lastHighestBid != 0){ // if there is a bid
                payable(lastHightestBidder).transfer(lastHighestBid); // refund the previous bid to the previous highest bidder
            }
        
            emit NewBid(msg.sender,msg.value); // emit a new bid event
            
            return true; // The bid was placed successfully
        }

    // Withdraw the token after the auction is over
    function withdrawToken() internal returns(bool)
        {
            require(getAuctionState() == AuctionState.ENDED || getAuctionState() == AuctionState.DIRECT_BUY); // The auction must be ended by either a direct buy or timeout
            require(msg.sender == maxBidder); // The highest bidder can only withdraw the token
            nft.transferFrom(creator, maxBidder, tokenId); // Transfer the token to the highest bidder
            emit WithdrawToken(maxBidder); // Emit a withdraw token event
            return true; // The token was withdrawn successfully
        }

    // Withdraw the funds after the auction is over
    function withdrawFunds(uint256 _fee) internal returns(bool)
        { 
            require(msg.sender == creator); // The auction creator can only withdraw the funds
            payable(creator).transfer(maxBid - _fee); // Transfers funds to the creator minus the fee
            emit WithdrawFunds(msg.sender,maxBid - _fee); // Emit a withdraw funds event
            return true; // The funds were withdrawn successfully
        } 
    // Cancel the auction
    function cancelAuction() public onlyManager returns(bool) 
        {   
            require(msg.sender == creator); // Only the auction creator can cancel the auction
            require(getAuctionState() == AuctionState.OPEN); // The auction must be open
            isCancelled = true; // The auction has been cancelled
            // Refund the highest bidder
            if(maxBid != 0){ // If there is a bid
                payable(maxBidder).transfer(maxBid); // refund the highest bid to the highest bidder
            }
            emit AuctionCanceled(); // Emit Auction Canceled event
            return true;
        } 

    // Get the auction state
    function getAuctionState() public view returns(AuctionState) 
        {
            if(isCancelled) return AuctionState.CANCELLED; // If the auction is cancelled return CANCELLED
            if(boughtNow) return AuctionState.DIRECT_BUY; // If the auction is ended by a direct buy return DIRECT_BUY
            if(block.timestamp >= endTime) return AuctionState.ENDED; // The auction is over if the block timestamp is greater than the end timestamp, return ENDED
            return AuctionState.OPEN; // Otherwise return OPEN
        } 
   
    // complete the purchase and collect fee
    function completePurchase() public onlyManager returns(bool)
        {
            // if the user has moved the NFT, cancel the auction
            if (creator != nft.ownerOf(tokenId)) {
                require(cancelAuction(), "Auction Failed to cancel");
                return false;
            }
            require(getAuctionState() == AuctionState.ENDED || getAuctionState() == AuctionState.DIRECT_BUY); // The auction must be ended by either a direct buy or timeout
            require(maxBidder != address(0), "Buyer can't be the null address"); // The highest bidder can not be the null address
            uint256 fee = maxBid * 1 / 10000; // The fee is 1% of the highest bid
            require(withdrawFunds(fee), "Auction Failed to withdraw funds"); // Withdraw the funds
            require(withdrawToken(), "Auction Failed to withdraw token"); // Withdraw the token
            return true;
        }
    // get creator
    function getCreator() public view returns(address)
        {
            return creator;
        }
}