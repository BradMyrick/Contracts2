// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


contract TimeGetter {
    function getTime() public view returns (uint256) {
        uint256 time = block.timestamp + 5 minutes; 
        return time;
    }

    function getTimePlusDays(uint64 _amount) public view returns (uint256) {
        uint256 time = _amount * 1 days;
        time += block.timestamp;
        return time;
    }
}