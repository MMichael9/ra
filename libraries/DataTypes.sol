// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library DataTypes {

    struct LoanData {
        address tokenOwner;
        address initiator;
        bool isApproved;
        uint256 borrowLimit;
        uint256 bor;
    }
}