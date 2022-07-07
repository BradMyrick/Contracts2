// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title Assembler Payment Contract
 * @notice Recieves AVAX from a creator and authorizes the NFT reveal to that user.
 */

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PaymentRecieved is Ownable, ReentrancyGuard {

    mapping(address => mapping(address => bool)) public Authorized;
    
    mapping(uint256 => uint256) public Prices;

    uint256 public increment = 1;

    event AuthorizedEvent(address indexed sender, address indexed nftContract);    

    function addPrice(_price) external onlyOwner {
        Prices[increment] = _price;
        increment++;
    }

    function authorize(uint256 _service, address _contract) external payable nonReentrant {
        require(msg.value >= Prices[_service], "Not enough Avax sent");
        Authorized[msg.sender][_contract] = true;
        emit AuthorizedEvent(msg.sender, _contract);
    }

    function isAuthorized(address _contract) public view returns (bool) {
        return Authorized[msg.sender][_contract];
    }
}