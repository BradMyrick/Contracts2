// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./rxgtoken.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

//------------------------------------------------------------------------------
// Staking contract
//------------------------------------------------------------------------------
/**
 * @title Paired
 * @dev terranart.eth
 * @dev 
 * ERC1155 contract that will take in a pair of tokens, one ERC20 and one base chain token
 * Contract will return a newly minted ERC1155 token with the staked pair information saved to it.
 * 
 * Unstaking will be done by burning the ERC1155 token.
 */
contract PairStaking is ERC1155Burnable, ERC1155Holder {
    using Counters for Counters.Counter;
// Variables
    Counters.Counter private tick;
    uint256 public constant MAX_UINT256 = 2**256 - 1;
    address public owner;
    address public stakedToken;
    address public baseToken;
    uint256 public tokenValue = 4;
    struct pair {
        address staker;
        uint256 baseAmount;
        uint256 ercAmount;
        uint256 tokenValue;
    }
// Modifiers
    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier isStaker(uint256 _id) {
        require(msg.sender == Pairs[_id].staker, "Only the staker can call this function");
        _;
    }
    

// Mappings
    mapping (uint256 => pair) public Pairs;
// Events
    event PairUnstaked(address indexed staker, uint256 value);
    event PairBurned(address indexed burner, uint256 value);
    event PairReturned(address indexed staker, uint256 value);
    event PairStaked(address indexed staker, uint256 ercAmount, uint256 baseAmount);
// Constructor
    constructor(address _stakedToken) ERC1155("Staking Information") { //TODO: add a base uri for staking information
        owner = msg.sender;
        baseToken = address(this);
        stakedToken = _stakedToken;
        tick = Counters.Counter(0);
        // counter for minting id's
    }
// Functions
    function mint() public payable returns (uint256 _id) {
        require(msg.value > 1, "Staking amount must be greater than 1 matic");
        uint256 baseAmount = msg.value;
        uint256 ercAmount = baseAmount * tokenValue;
        uint256 id = tick.current();
        tick.increment();
        Pairs[id] = pair(msg.sender, baseAmount, ercAmount, tokenValue);
        IERC20 paymentToken = IERC20(stakedToken);
        require(paymentToken.transferFrom(msg.sender, address(this), (Pairs[_id].ercAmount)), "Failed to transfer tokens");
        bytes memory data = "0x0";
        _mint(msg.sender, _id, 1, data);
        emit PairStaked(msg.sender, (Pairs[_id].ercAmount), (Pairs[_id].baseAmount));
        return id;
    }


    function unstake(uint256 id) public {
        require(balanceOf(msg.sender, id) > 0, "Staked amount must be greater than 0");
        require(id > 0, "ID must be greater than 0");
        require(id <= tick.current(), "ID must be less than or equal to the current counter");
        uint256 baseAmount = Pairs[id].baseAmount;
        uint256 ercAmount = Pairs[id].ercAmount;
        // ensure the contract has enough balance to unstake
        IERC20 paymentToken = IERC20(stakedToken);
        IERC20 paymentMatic = IERC20(baseToken);
        require(ercAmount <= paymentToken.balanceOf(address(this)), "ERC20 amount must be less than or equal to the current ERC balance");
        require(baseAmount <= paymentMatic.balanceOf(address(this)), "Base amount must be less than or equal to the current base balance");
        // transfer the staked amount of ERC20 Token and base token to the user
        require(paymentToken.transferFrom(address(this), msg.sender, ercAmount), "Failed to transfer ERC amount");
        require(paymentMatic.transferFrom(address(this), msg.sender, baseAmount), "Failed to transfer base amount");
        // detroy the pair
        burn(msg.sender, id, 1);
        emit PairUnstaked(msg.sender, ercAmount);

    }

    // override supportsInterface
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Receiver) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

}