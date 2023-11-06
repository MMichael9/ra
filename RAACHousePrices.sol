// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// This contract will store and fetch the house price for each 
// property. Integrate with chainlink feeds to be able to 
// dynamically fetch and update property values
// Currently using preset values for prices

import "@openzeppelin/contracts/access/Ownable.sol";


contract RAACHousePrices is Ownable {
    uint256[] public housePrices = [25000e18, 50000e18, 100000e18, 500000e18];

    constructor() {}

    function setHousePrices(uint256[] memory prices) external onlyOwner {
        housePrices = prices;
    }
}