// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// contract is used to control acess by checking if the caller has the erc721 token required to use the service. 
// then assign the user a role.

contract AccessTacvue{
    //variables
    address public owner;
    address private _entityAddress;
    //constructor
    constructor(address _entityAddress){
        //initialize the variables
        owner = msg.sender;
        this._entityAddress = _entityAddress;

    }
    //functions

    // auction access
    function auctionAccess(address _user) public{
        //check if the user owns an entitiy card erc721 token

}