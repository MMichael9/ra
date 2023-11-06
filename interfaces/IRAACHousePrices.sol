// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRAACHousePrices {
    function housePrices(uint256 _tokenId) external view returns(uint256);
}