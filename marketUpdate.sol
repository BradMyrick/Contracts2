// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AuctionManager {
    uint _auctionIdCounter; // auction Id counter
    address public token;
    address public owner; // owner of the contract
    address public wallet; // wallet address
// modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
// mappings
    mapping (address => uint[] ) public Bids; // mapping of address to bid array
    mapping(uint => Auction) public auctions; // auctions
// events
    event Received(address, uint);
// constructor
    constructor(address _token) {
        owner = msg.sender; //TODO: multisig
        wallet = msg.sender;
        _auctionIdCounter = 0;
        token = _token;
    }
// functions
    // receive base token
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    // set owner
    function setOwner(address _owner) onlyOwner public {
        owner = _owner;
    }
    // set wallet
    function setWallet(address _wallet) onlyOwner public {
        wallet = _wallet;
    }
    // create an auction
    function createAuction(uint _endTime, uint _minIncrement, uint _directBuyPrice,uint _startPrice,address _nftAddress,uint _tokenId) external returns (bool)
        {
            IERC721 nftToken = IERC721(_nftAddress);
            require(nftToken.isApprovedForAll(msg.sender, address(this))); // check if the sender has approved the contract
            require(nftToken.ownerOf(_tokenId) == msg.sender, "You are not the owner of this token");
            require(_directBuyPrice >= 0); // direct buy price must be greater than 0
            require(_startPrice < _directBuyPrice); // start price is smaller than direct buy price
            require(_endTime > 59 minutes); // end time must at least one hour to allow for block confirmation

            uint auctionId = _auctionIdCounter; // get the current value of the counter
            _auctionIdCounter++; // increment the counter
            Auction auction = new Auction(msg.sender, _endTime, _minIncrement, _directBuyPrice, _startPrice, nftToken, _tokenId); // create the auction
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
                highestBid[i] = Auction(auctions[i]).getMaxBid(); // get the highest bid
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


    // cancel auction
    function cancelAuction(address _auctionAddress) external returns (bool)
        {
            require(Auction(_auctionAddress).getCreator() == msg.sender || owner == msg.sender); // only the creator or the owner can cancel the auction
            Auction(_auctionAddress).cancelAuction(); // cancel the auction
            return true;
        }

    // buy it now
    function buyItNow(address _auctionAddress) external payable returns (bool)
        {
            address creator = Auction(_auctionAddress).creator(); // get the creator of the auction
            require(creator != msg.sender ); // the creator cannot buy it now
            uint256 directBuyPrice = Auction(_auctionAddress).directBuyPrice(); // get the direct buy price
            require(msg.value >= directBuyPrice); // the sender must pay the direct buy price
            require(Auction(_auctionAddress).buyNow(msg.sender)); // buy it now
            uint256 fee = msg.value / 100; // calculate the fee
            uint256 profit = msg.value - fee; // calculate the profit
            // transfer the recieved base token to the creator
            address payable pcreator = payable(creator);
            pcreator.transfer(profit);         
            return true;
        }
    // bid on an auction TODO: Bid tokens - issue a token with a bidders value so we can ensure the avax is held and allow for multiple bidding
    function bid(address _auctionAddress, uint256 _bid, uint256 _endTime) external returns (bool)
        {
            // require the manager is approved to transfer bids from the sender
            require(Auction(_auctionAddress).getCreator() != msg.sender); // the creator cannot bid on his own auction
            // TODO: add bot protection
            //Bids[msg.sender].push(Auction(_auctionAddress).placeBid(msg.sender, _bid, _endTime));
            return true;
        }
    // withdraw bid.
    function withdrawBid(address _auctionAddress, uint256 _bidId) external returns (bool)
        {
            require(Auction(_auctionAddress).getCreator() != msg.sender); // the creator cannot withdraw his own bid
            Auction(_auctionAddress).cancelBid(_bidId, msg.sender); // withdraw the bid
            return true;
        }

    // complete an auction
    function completeAuction(address _auctionAddress) external onlyOwner returns (bool)
        {
            IERC20 dp = IERC20(token); // get the wrapped token
            uint256 amount = Auction(_auctionAddress).getMaxBid(); // get the winning bid
            address highestBidder = Auction(_auctionAddress).getMaxBidder(); // get the highest bidder
            address creator = Auction(_auctionAddress).creator(); // get the creator of the auction
            require(highestBidder != Auction(_auctionAddress).creator()); // no bidders
            require(amount > 0, "0 bid"); // no bid
            uint256 allowance = dp.allowance(msg.sender, address(this));
            require(allowance >= amount, "Check the token allowance");
            uint256 fee = Auction(_auctionAddress).getMaxBid() / 100; // calculate the fee
            uint256 profit = Auction(_auctionAddress).getMaxBid() - fee; // calculate the profit
            require(dp.transferFrom(highestBidder, wallet, fee), "Failed to transfer the tokens");
            require(dp.transferFrom(highestBidder, creator, profit), "Failed to transfer the tokens");
            require(Auction(_auctionAddress).completeAuction()); // complete the auction
            return true;
        }

    // withdraw auction fees
    function withdraw() external onlyOwner returns (bool)
        {
            payable(wallet).transfer(address(this).balance);
            return true;
        }

    // destroy an auction
    function destroyAuction(address _auctionAddress) external onlyOwner returns (bool)
        {
            require(Auction(_auctionAddress).getAuctionState() == Auction.AuctionState.ENDED || Auction(_auctionAddress).getAuctionState() == Auction.AuctionState.CANCELLED,"The auction must have ended"); // the auction must be complete
            require(Auction(_auctionAddress).kill()); // kill the auction
            return true;
        }

}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract Auction {
// variables
    address public manager;
    uint256 public endTime; // Timestamp of the end of the auction (in seconds)
    uint256 public startTime; // The block timestamp which marks the start of the auction
    uint public maxBid; // The maximum bid
    address public maxBidder; // The address of the maximum bidder
    address public creator; // The address of the auction creator
    Bid[] public bids; // The bids made by the bidders
    uint public tokenId; // The id of the token
    bool public isCancelled; // If the the auction is cancelled
    bool public _buyNow; // Can be purchased now
    uint public minIncrement; // The minimum increment for the bid  
    uint public directBuyPrice; // The price for a direct buy
    uint public startPrice; // The starting price for the auction
    bool private purchased;

    IERC721 nft; // The NFT token

    enum AuctionState { 
        OPEN,
        CANCELLED,
        ENDED
    }

    struct Bid { // A bid on an auction
        address sender;
        uint256 bid;
        uint256 endTime;
        bool active;
    }
// modifiers
    modifier onlyManager() {
        require(msg.sender == manager);
        _;
    }
// mapping
    mapping (address => uint[]) public bidIndex; // mapping from bid to index

// events
    event NewBid(address bidder, uint256 bid, uint256 endTime); // A new bid was placed
    event WithdrawToken(address withdrawer); // The auction winner withdrawed the token
    event WithdrawFunds(address withdrawer, uint256 amount); // The auction owner withdrew the funds
    event AuctionCanceled(); // The auction was cancelled
// constructor
    constructor(address _creator,uint _endTime,uint _minIncrement,uint _directBuyPrice, uint _startPrice,IERC721 _nftAddress,uint _tokenId)
        {
            if (_directBuyPrice > 0) {
                _buyNow = true;
            } else {
                _buyNow = false;
            }
            manager = msg.sender;
            creator = _creator; // The address of the auction creator
            endTime = block.timestamp +  _endTime; // The timestamp which marks the end of the auction (now + 30 days = 30 days from now)
            startTime = block.timestamp; // The timestamp which marks the start of the auction
            minIncrement = _minIncrement; // The minimum increment for the bid
            directBuyPrice = _directBuyPrice; // The price for a direct buy
            startPrice = _startPrice; // The starting price for the auction
            nft = _nftAddress; // The address of the nft token
            tokenId = _tokenId; // The id of the token
            maxBidder = _creator; // Setting the maxBidder to auction creator.
        }

// functions

    // Returns a list of all bids and addresses
    function allBids()
        external
        view
        returns (Bid[] memory _bids)
        {
            for (uint i = 0; i < bids.length; i++) {
                _bids[i] = bids[i];
            }
        }

    // get max bid
    function getMaxBid()
        external
        view
        returns (uint256 _maxBid)
        {
            return maxBid;
        }
    
    // get max bidder
    function getMaxBidder()
        external
        view
        returns (address _maxBidder)
        {
            return maxBidder;
        }

    // Place a bid on the auction
    function placeBid(uint256 _amount, address _bidder, uint256 _endTime) payable external returns(bool)
        {
            require(msg.sender != creator, 'Do not bid on your own item.'); // The auction creator can not place a bid
            require(msg.value >= _amount, 'Your balance is too low.'); // The sender must have enough balance to place a bid
            require(getAuctionState() == AuctionState.OPEN); // The auction must be open
            require(_amount >= startPrice, 'The bid is too low'); // The bid must be higher than the starting price
            require(_amount >= maxBid + minIncrement, 'The bid is too low'); // The bid must be higher than the current bid + the minimum increment
            require(creator == nft.ownerOf(tokenId), 'The token has been moved'); // The token must belong to the creator
            maxBid = _amount; // The new highest bid
            maxBidder = _bidder; // The address of the new highest bidder
            Bid memory bid = Bid(_bidder, _amount, _endTime, true); // The bid
            bids.push(bid); // Add the bid to the bids array
            uint index = bids.length - 1; // The index of the bid
            bidIndex[_bidder].push(index); // Add the index to the bidIndex array
            emit NewBid(_bidder,_amount, _endTime); // emit a new bid event
            
            return true;
        }

    // Buy Now
    function buyNow(address _buyer) payable external returns (bool)
        {
            require(_buyNow == true); // The auction must be buy now
            require(creator == nft.ownerOf(tokenId), 'The token has been moved'); // The token must belong to the creator
            nft.safeTransferFrom(creator, _buyer, tokenId); // Transfer the token to the buyer
            emit WithdrawToken(_buyer); // emit a withdraw token event
            purchased = true; // The auction has ended due to purchase
            return true; // The token was bought successfully
        }

 
    // Cancel the auction
    function cancelAuction() public onlyManager returns(bool) 
        {   
            require(getAuctionState() == AuctionState.OPEN); // The auction must be open
            isCancelled = true; // The auction has been cancelled
            emit AuctionCanceled(); // Emit Auction Canceled event
            return true;
        } 

    // Get the auction state
    function getAuctionState() public view returns(AuctionState) 
        {
            if(isCancelled) return AuctionState.CANCELLED; // If the auction is cancelled return CANCELLED
            // if(_buyNow) return AuctionState.DIRECT_BUY; // If the auction is ended by a direct buy return DIRECT_BUY
            if(block.timestamp >= endTime) return AuctionState.ENDED; // The auction is over if the block timestamp is greater than the end timestamp, return ENDED
            if(purchased) return AuctionState.ENDED; // If the auction is ended return ENDED
            return AuctionState.OPEN; // Otherwise return OPEN
        } 
   
    // get creator
    function getCreator() public view returns(address)
        {
            return creator;
        }
    // cancel bid
    function cancelBid(uint _bidIndex, address _bidder) external onlyManager returns(bool)
        {
            require(_bidIndex < bids.length, "Index out of range"); // The bid index must be less than the number of bids
            require(bids[_bidIndex].sender == _bidder, "The bid is not yours"); // The bid must be from the bidder
            require(bids[_bidIndex].active, "Bid is inactive"); // The bid must be active
            bids[_bidIndex].active = false; // The bid is not active
            return true;
        }
    // complete auction
    function completeAuction() external onlyManager returns(bool)
        {
            require(getAuctionState() == AuctionState.ENDED); // The auction must be ended
            require(nft.ownerOf(tokenId) == creator, "The token has been moved"); // The token must belong to the creator
            nft.safeTransferFrom(creator, maxBidder, tokenId); // Transfer the token to the highest bidder
            emit WithdrawToken(maxBidder); // Emit Withdraw Token event
            purchased = true; // The auction has ended due to purchase
            return true;
        }
    // kill function
    function kill() external onlyManager returns(bool)
        {
            require(getAuctionState() == AuctionState.ENDED); // The auction must be ended
            selfdestruct(payable(manager)); // Selfdestruct the contract
            return true;
        }
}
