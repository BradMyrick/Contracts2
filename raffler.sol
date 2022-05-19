// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Take an ERC721 token, an number of entrants, and a ticket price. 
// Then create a raffle when all of the entrants have joined by paying the ticket price.

contract raffle is ReentrancyGuard{
    using SafeMath for uint;

    ERC721 token;
    uint256 tokenId;
    address owner;
    uint256 maxTickets;
    uint256 totalSold;
    uint256 price;

}