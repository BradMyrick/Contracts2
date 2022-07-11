// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

library StringCheck {
    /// @dev Does a byte-by-byte lexicographical comparison of two strings.
    /// @return a negative number if `_a` is smaller, zero if they are equal
    /// and a positive numbe if `_b` is smaller.
    function _compare(string memory _a, string memory _b) internal pure returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        //@todo unroll the loop into increments of 32 and do full 32 byte comparisons
        for (uint i = 0; i < minLength; i ++)
            if (a[i] < b[i])
                return -1;
            else if (a[i] > b[i])
                return 1;
        if (a.length < b.length)
            return -1;
        else if (a.length > b.length)
            return 1;
        else
            return 0;
    }
    /// @dev Compares two strings and returns true iff they are equal.
    function equal(string memory _a, string memory _b) public pure returns (bool) {
        return _compare(_a, _b) == 0;
    }
}


import "github.com/chiru-labs/ERC721A/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Entity ERC721A
 * @notice Tacvue Genesis Entity NFT Token Standard for ERC721A with post minting URI reveal
 * @dev Enter the placeholder URI for the placeholder image during contract deployment
 * @author BradMyrick @kodr_eth
 */

contract Entity721a is ERC721A, Ownable, ReentrancyGuard { 
    uint256 public MAX_SUPPLY; 
    string public placeHolderURI;

    // token uri mapping
    mapping(uint256 => string) public tokenURIs;

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender, "Only the token owner can call this function");
        _;
    }

    constructor(uint256 _maxSupply, string memory _placeholderURI) ERC721A("Genesis Entity", "TVGE"){
        MAX_SUPPLY = _maxSupply;
        placeHolderURI = _placeholderURI;
    }

    function mint(uint256 quantity) external nonReentrant {
        // only one entity can be held by a wallet
        require(balanceOf(msg.sender) == 0, "You already have a genesis");
            _safeMint(msg.sender, quantity);
    }

    // function to set the token URI for a minted token
    function setTokenURI(string memory _URI, uint256 _tokenId) external onlyTokenOwner(_tokenId) {
        require(StringCheck.equal(tokenURIs[_tokenId], placeHolderURI), "You can only set the URI for a token once");
        tokenURIs[_tokenId] = _URI;       
    }

    // override the tokenURI function in ERC721A
    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        return tokenURIs[_tokenId];
    }

}