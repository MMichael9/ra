// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Vault contract handles depositing / withdrawing of RAAC NFTs
// Each RAAC NFT represents an underlying property
// Depositing token allows borrowing against it

import "./interfaces/IRAACLendingPool.sol";
import "./interfaces/IRAACForclosureLane.sol";
import "./interfaces/IRAACHousePrices.sol";
import "erc721a/contracts/IERC721A.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RAACVault is Ownable, IERC721Receiver {

    // Interfaces
    IERC721A public raacInterface;
    IRAACLendingPool public lpInterface;
    IRAACForclosureLane public fclInterface;
    IRAACHousePrices public hpInterface;

    mapping(uint256 => address) public originalOwner;

    event DepositNFT(address indexed tokenOwner, uint256 tokenId, uint256 housePrice, uint256 borrowLimit);
    event WithdrawNFT(address indexed tokenOwner, uint256 tokenId);
    event LiquidateNFT(address indexed tokenOwner, uint256 tokenId, uint256 housePrice, uint256 repayAmount, uint256 ltv);
    

    constructor(address _raacAddress, address _lendingpool, address _fclAddress, address _housePrices) {
        raacInterface = IERC721A(_raacAddress);
        lpInterface = IRAACLendingPool(_lendingpool);
        fclInterface = IRAACForclosureLane(_fclAddress);
        hpInterface = IRAACHousePrices(_housePrices);
    }

    // Deposit NFT into Vault
    function stakeNFT(uint256 tokenId) external {
        uint256 borrowLimit = hpInterface.housePrices(tokenId);
        // set updated loan data in lending pool
        lpInterface.setLoanData(tokenId, msg.sender, true, borrowLimit);

        raacInterface.safeTransferFrom(msg.sender, address(this), tokenId);
        emit DepositNFT(msg.sender, tokenId, hpInterface.housePrices(tokenId), borrowLimit);
    }

    // Withdraw NFT from vault
    function withdrawNFT(uint256 tokenId) external {
        require(originalOwner[tokenId] == msg.sender, "Non-token owner can't withdraw");
        require(lpInterface.getLoanAmount(tokenId) == 0, "OutstandingLoan");
        
        originalOwner[tokenId] = address(0);

        // reset loan data in lending pool
        lpInterface.setLoanData(tokenId, address(0), false, 0);

        raacInterface.safeTransferFrom(address(this), msg.sender, tokenId);
        emit WithdrawNFT(msg.sender, tokenId);
    }

    // Liquidate NFT if outstanding borrow exceeds property value
    function liquidateNFT(uint256 tokenId) external {
        require(raacInterface.ownerOf(tokenId) == address(this), "TokenNotVaulted");
        uint256 loanAmount = lpInterface.getLoanAmount(tokenId);
        require(loanAmount > 0, "NoLoan");

        uint256 health = 0.85e18;
        uint256 ltv = getLTV(tokenId);

        // perform liquidation if loan value surpasses health
        if(ltv > health) {
            uint256 startingPrice = lpInterface.getFullRepayment(tokenId);
            address og = originalOwner[tokenId];
            originalOwner[tokenId] = address(0);
            lpInterface.setLoanData(tokenId, address(0), false, 0);

            raacInterface.approve(address(fclInterface), tokenId);
            fclInterface.sendForclosure(tokenId, og, startingPrice);

            emit LiquidateNFT(originalOwner[tokenId], tokenId, hpInterface.housePrices(tokenId), startingPrice, ltv);
        }
    }

    function getHousePrice(uint256 tokenId) public view returns(uint256) {
        return hpInterface.housePrices(tokenId);
    }

    // Return NFT loan to value
    function getLTV(uint256 tokenId) public view returns(uint256) {
        return lpInterface.getFullRepayment(tokenId) * 1e18 / hpInterface.housePrices(tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        originalOwner[tokenId] = from;
        return IERC721Receiver.onERC721Received.selector;
    }
}