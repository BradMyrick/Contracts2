// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title Terran ERC721A
 * @notice Tacvue NFT Token Standard for ERC721A with post minting URI reveal
 * @dev Enter the placeholder URI for the placeholder image during contract deployment
 * @dev No decoded a Whitelist that can be exploited to mint tokens during a Whitelist phase, add WL participants with addToWhiteList(address _addr).
 *      Once the Whitelist sale has been started, toggling on the saleIsActive bool will disable the whitelist and allow the sale to start. 
 * @dev Assumptions (not checked, assumed to be always true):
 *        1) When assigning URI's to token IDs, the caller verified the URI is valid and matched to the token ID list provided.
 *        2) ERC721A Security meets the requirements of the ERC721 NFT standard,
 *        3) Number of tokens does not exceed `(2**256-1)/(2**96-1)`. Tested: 10,000
 * @author BradMyrick @terran_nft 
 */


import "github.com/chiru-labs/ERC721A/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Tacvue721a is ERC721A, Ownable {
    uint256 public MAX_MINTS; 
    uint256 public MAX_SUPPLY; 
    uint256 public mintPrice;   
    uint256 public WLprice;     
    string public _PlaceHolderURI;
    bool public wlActive = false;
    bool public saleIsActive = false;
    string private _emptyURI = "";

    mapping(address => uint256) public walletMints; // number of times an address has minted
    mapping(uint256 => string) private tokenURIs; // URI of the token
    mapping(address => bool) public WhiteList; // token id to token URI

    constructor(string memory _name, string memory _ticker, uint256 _maxMints, uint256 _maxSupply, uint256 _mintPrice, uint256 _wlPrice, string memory _placeholderURI) ERC721A(_name, _ticker){
        MAX_MINTS = _maxMints;
        MAX_SUPPLY = _maxSupply;
        mintPrice = _mintPrice;
        WLprice = _wlPrice;
        _PlaceHolderURI = _placeholderURI;
    }

    function mint(uint256 quantity) external payable {
        require(saleIsActive != wlActive, "Minting Has Been Disabled");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Max Supply Reached");
        walletMints[msg.sender] += quantity;
        require(walletMints[msg.sender] <= MAX_MINTS, "Max mints reached, lower amount to mint");
        if (wlActive) {
            require(WhiteList[msg.sender], "Not whitelisted");
            require(msg.value >= (WLprice * quantity), "Not enough Avax sent");
            _safeMint(msg.sender, quantity);
        } else {
            require(saleIsActive, "Sale not active");
            require(msg.value >= (mintPrice * quantity), "Not enough Avax sent");
            _safeMint(msg.sender, quantity);
        }
    }

    function addToWhiteList(address _addr) external onlyOwner {
        require(!WhiteList[_addr], "Already whitelisted");
        WhiteList[_addr] = true;
    }

    function removeFromWhiteList(address _addr) external onlyOwner {
        require(WhiteList[_addr], "Not whitelisted");
        WhiteList[_addr] = false;
    }

    function withdraw() external payable onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function saleActiveSwitch() public onlyOwner {
        if (wlActive){ wlActive = false;}
        saleIsActive = !saleIsActive;
    }

    function WlActiveSwitch() public onlyOwner {
        wlActive = !wlActive;
    }

    // take a list of token URIs and set them as the token URIs for all tokens   
    // To seal this function revoke ownership after reveal is complete
    function setTokenURIs(uint256[] calldata _ids,string[] calldata _tokenURIs) public onlyOwner {
        require(_ids.length == _tokenURIs.length, "Length of ids and URIs must match");
        for (uint256 i = 0; i < _ids.length; i++) {
            tokenURIs[_ids[i]] = _tokenURIs[i];
        }
    }
    // Ovveride the ERC721A function to get the URI of the token
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) revert URIQueryForNonexistentToken();
        if (abi.encodePacked(tokenURIs[_tokenId]).length == 0) return _PlaceHolderURI;
        else {return tokenURIs[_tokenId];}
    } 
}