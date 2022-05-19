// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// contract to like an NFT and save those likes to the blockchain

contract Liker {
// public variables
    address public addressNFT;
    uint public totalCollectionLikes;
// mapping
    mapping(uint256 => uint) public likes;

// constructor
    constructor(address _nftContract){
        require(_nftContract != address(0), "The address of the contract is not specified.");
        addressNFT = _nftContract;
    }
// functions
    // like an NFT
    function like(uint _nftId) public{
        likes[_nftId]++;
        totalCollectionLikes++;
    }

    // remove like
    function unlike(uint _nftId) public{
        likes[_nftId]--;
        totalCollectionLikes--;
    }

    // get number of likes for a single NFT in the collection
    function getIdLikes(uint _nftId) public view returns (uint){
        return likes[_nftId];
    }

    // get total number of likes for collection
    function getTotalLikes() public view returns (uint){
        return totalCollectionLikes;
    }

}