//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @title EventAuth
 * @dev This contract is used to charge an amount of an ERC20 token to give authorization to post an event.
 * @author Brad Myrick
 */


contract EventAuth is ReentrancyGuard {
    using EnumerableSet for EnumerableSet.Bytes32Set;
// variables
    ERC20Burnable token;
    uint256 public eventPrice;
    EnumerableSet.Bytes32Set private authorizedIDs;
    uint256 private ticker;

// mappings
    mapping (address => mapping (bytes32 => bool)) private authorized;
// constructor
    constructor(address _token, uint256 _eventPrice){
        // initialize variables
        token = ERC20Burnable(_token);
        eventPrice = (_eventPrice * (1 wei)); // rxg wei
        ticker = 0;
        // initialize mappings
    }
// functions

    function grantAccess() external nonReentrant() returns(bytes32 _authID){
        address _eventCreator = msg.sender;
        // check if event creator is authorized
        require(token.allowance(_eventCreator, address(this)) >= eventPrice, "You must pay rxg to grant access to post an event.");
        ticker++;
        // create unique uint ID
        uint256 id = block.timestamp + block.number + ticker;
        // randomize ID
        bytes32 randomID = keccak256(abi.encodePacked(id));
        // add ID to authorizedIDs
        authorizedIDs.add(randomID);
        // add ID to authorized
        authorized[_eventCreator][randomID] = true;
        emit EventCreated(randomID, _eventCreator);
        // burn rxg
        token.burnFrom(_eventCreator, eventPrice);
        return randomID;
    }

    function revokeAccess(bytes32 _authID) external returns(bool _success){
        // check if authID is in authorizedIDs
        require(authorizedIDs.contains(_authID), "ID does not exist.");
        require(authorized[msg.sender][_authID], "You are not authorized to revoke access.");
        // remove from authorized
        authorized[msg.sender][_authID] = false;
        // remove authID from authorizedIDs
        authorizedIDs.remove(_authID);
        emit EventRevoked(_authID, msg.sender);
        return true;
    }

    function checkAccess(bytes32 _authID) external view returns(bool _success){
        // check if authID is in authorizedIDs
        if(!authorized[msg.sender][_authID]){
            return false;
        }
        return true;
    }

// events
    event EventCreated(bytes32 indexed authID, address indexed eventCreator);
    event EventRevoked(bytes32 indexed authID, address indexed eventCreator);
}