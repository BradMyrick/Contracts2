// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract Recharge is ERC777 {
    uint256 initialSupply = 10000000000 ether; // 10 billion tokens
    constructor()
        public
        ERC777("Recharge", "RXG", new address[](0))
    {
        _mint(msg.sender, initialSupply, "", "");
    }
}
