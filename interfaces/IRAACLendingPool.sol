// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../libraries/DataTypes.sol";

interface IRAACLendingPool {
    function borrow(uint256 _tokenId, uint256 _amount) external;
    function repay(uint256 _tokenId, uint256 _bor) external;

    function getLoanData(uint256 _tokenId) external view returns (DataTypes.LoanData memory);
    function getTokenOwner(uint256 _tokenId) external view returns (address);
    function getLoanAmount(uint256 _tokenId) external view returns (uint256);
    function getFullRepayment(uint256 _tokenId) external view returns (uint256);
    function setLoanData(uint256 _tokenId, address _tokenOwner, bool _isApproved, uint256 _borrowLimit) external;
}