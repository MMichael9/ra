// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Mock token to represent functionality of any ERC20

// crvUSD will be used as it can then be deposited 
// through CRV and CVX to boost rewards

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RAACMockERC20 is ERC20, Ownable {
    constructor() ERC20("Mock CRVUSD", "MCRVUSD") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }

    function mintTo(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}