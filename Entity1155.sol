// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0)
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract ENTITY1155 is Context, ERC1155Burnable, Ownable {
    uint256 public constant GENESIS = 0;
    uint256 public constant LEGENDARY = 1;
    uint256 public constant RARE = 2;
    uint256 public constant COMMON = 3;
    uint256 public GenesisSupply;
    uint256 public LegendarySupply;
    uint256 public RareSupply;
    uint256 public CommonSupply;
    uint256 public  GenesisMax;
    uint256 public  LegendaryPrice;
    uint256 public  RarePrice;
    uint256 public  CommonPrice;
    mapping(uint256 => bool ) public MintIsLive;

    constructor(string memory uri, uint256 genesisMax, uint256 legendaryPrice, uint256 rarePrice, uint256 commonPrice) ERC1155(uri) {
        GenesisMax = genesisMax;
        GenesisSupply = 0;
        LegendarySupply = 0;
        RareSupply = 0;
        CommonSupply = 0;
        LegendaryPrice = legendaryPrice;
        RarePrice = rarePrice;
        CommonPrice = commonPrice;
        MintIsLive[GENESIS] = true;
        MintIsLive[LEGENDARY] = false;
        MintIsLive[RARE] = false;
        MintIsLive[COMMON] = false;
    }


    function mintGenesis() external {
        // only 1 per wallet
        require(balanceOf(msg.sender, GENESIS) == 0, "You already have a genesis");
        require(MintIsLive[GENESIS] == true, "Minting is not live");
        require(GenesisSupply < GenesisMax, "Genesis supply is full");
        GenesisSupply++;
        bytes memory data = abi.encodePacked(GenesisSupply);
        _mint(msg.sender, GENESIS, 1, data);
    }

    function mintLegendary() external payable {
        // only 1 per wallet
        require(balanceOf(msg.sender, LEGENDARY) == 0, "You already have a legendary");
        require(MintIsLive[LEGENDARY] == true, "Minting is not live");
        require(msg.value == LegendaryPrice, "You must pay the correct price");
        LegendarySupply++;
        bytes memory data = abi.encodePacked(LegendarySupply);
        _mint(msg.sender, LEGENDARY, 1, data);
    }

    function mintRare() external payable {
        // only 1 per wallet
        require(balanceOf(msg.sender, RARE) == 0, "You already have a rare");
        require(MintIsLive[RARE] == true, "Minting is not live");
        require(msg.value == RarePrice, "You must pay the correct price");
        RareSupply++;
        bytes memory data = abi.encodePacked(RareSupply);
        _mint(msg.sender, RARE, 1, data);
    }

    // set the minting to live or not live
    function setMinting(uint256 _tokenId, bool _live) external onlyOwner() {
        MintIsLive[_tokenId] = _live;
    }

    // withdraw funds from the contract
    function withdraw() external onlyOwner {
        uint bal = address(this).balance;
        payable(owner()).transfer(bal);
   }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}