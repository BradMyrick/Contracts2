
            // check if the link is a valid twitter link
        require(_isValidTweet(_link), "Invalid tweet link");
    
    function _substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory ) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
    }
    return string(result);
    }

    function _isValidTweet(string memory _link) internal pure returns (bool _success) {
        // check if the link starts with https://twitter.com/
        string memory _substr = _substring(_link, 0, 21);
        require(keccak256(abi.encodePacked(_substr)) == keccak256(abi.encodePacked("https://twitter.com/")), "Invalid tweet link");
        return true;
    }