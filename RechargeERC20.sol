// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @dev {ERC20} RXG token, including:
 *
 *  - Preminted initial supply of 10 billion tokens
 *  - Ability for holders to burn (destroy) their tokens
 *  - No access control mechanism (for minting/pausing) and hence no governance
 *
 * This contract uses {ERC20Burnable} to include burn capabilities - head to
 * its documentation for details.
 */
contract RechargeERC20 is ERC20Burnable {
    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {ERC20-constructor}.
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        uint256 initialSupply = 10000000000 ether; // 10 billion 10,000,000,000
        _mint(msg.sender, initialSupply);
    }
}