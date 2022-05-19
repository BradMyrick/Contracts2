// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract OneByOne721 is ERC721Enumerable, ERC721Burnable, Ownable{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;
    
// mapping
    mapping(uint256 => string) private _tokenURIs;
    
// constructor
    constructor(string memory _name, string memory _ticker) ERC721( _name, _ticker){ }   
// functions
/**
 * @dev mint function for contract creator to add collectibles one by one
 */
    function mint(string memory _tokenURI) public virtual onlyOwner{
        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        require(bytes(_tokenURI).length !=0, "Url token is empty.");

        _tokenIdTracker.increment();
        // set the tokenURI
        setTokenURI(_tokenIdTracker.current(), _tokenURI);
        _mint(msg.sender, _tokenIdTracker.current());
        
    }

        function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override( ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


        /**
     * @dev set token URI for a given token ID
     */
    function setTokenURI(uint256 _tokenId, string memory _URI) internal {
        _tokenURIs[_tokenId] = _URI;

    }

        /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }
}