// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRAACForclosureLane {
     function sendForclosure(uint256 _tokenId, address _originalOwner, uint256 _startingPrice) external;
}