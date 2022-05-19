// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

// This contract is used to retrieve information from multiple contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Getter{
// Variables
    address public manager;
    address public owner;
    address[] public contracts;
    uint256 public lastTime;
    uint256 public prevVolume;
    uint256 public curVolume;
// Modifiers
    modifier onlyManager{
        require(msg.sender == manager);
        _;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
// Events
    event Log(string);

// Constructor
    constructor (address _manager){
        manager = _manager;
        owner = msg.sender;
        lastTime = block.timestamp;
    }
// Functions
    // Get Marketplace 24hr volume
    function getMarketplaceTransfers() external view returns (uint256){
        uint256 transfers = 0;
        // set the deployed contract to variable
        // marketplace 
        // get the amount of AVAX transfered buy the marketplace contract since lastTime
        //transfers = marketplace.getVolume();
        //curVolume = transfers - prevVolume;
        //prevVolume = transfers;

        return transfers;
    }

    // add a contract to the array of contracts
    function addContract(address _contract, uint _index) onlyManager public{
        // check if the contract is already in the array
        if(contracts[_index] == _contract){
            emit Log("Contract already at this position");
            return;
        }
        // check if the index is already in use
        if(contracts[_index] != address(0)){
            emit Log("Index already in use, remove the contract first");
            return;
        }
        // add the contract to the array
        contracts[_index] = _contract;
    }

    // remove a contract from the array of contracts
    function removeContract(address _contract, uint _index) onlyManager public{
        // check if the contract is already in the array
        if(contracts[_index] != _contract){
            emit Log("Contract not at this position");
            return;
        }
        // remove the contract from the array
        contracts[_index] = address(0);
    }

    // return all contracts
    function getContracts() external view returns (address[] memory){
        return contracts;
    }

    // return the top 10 RXG erc20 token holders
    function getTop10Holders() external view returns (address[] memory){
        //address[] top10Holders = new address[10];
        //uint256[] top10Balances = new uint256[10];
        // set the deployed contract to variable
        ERC20 token = ERC20(contracts[1]);
        // get the top 10 holders
    }
}