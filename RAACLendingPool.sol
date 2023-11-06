// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Lend Pool contract with a very basic interest bearing mechanism
// allows users to deposit, withdraw, borrow and repay

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/DataTypes.sol";


contract RAACLendingPool is Ownable, ERC20 {
    using SafeERC20 for IERC20;
    
    struct RateInfo {
        uint256 optimal;
        uint256 base;
        uint256 low;
        uint256 high;
    }

    mapping(uint256 => DataTypes.LoanData) public loans;

    RateInfo public rateInfo;
    uint256 public lastUpdate;
    IERC20 token;
    uint256 public totalBorrow;
    uint256 public index = 1e18;

    event Deposit(address indexed initiator, uint256 amount, uint256 sha);
    event Withdraw(address indexed initiator, uint256 amount, uint256 sha);
    event Borrow(address indexed initiator, uint256 indexed tokenId, address indexed borrower, uint256 amount, uint256 bor);
    event Repay(uint256 indexed tokenId, address indexed tokenHolder, uint256 borrowAmt, uint256 repayAmt);

    constructor(RateInfo memory _rateInfo, address _token) ERC20("RAAC Interest Bearing token", "token") {
        lastUpdate = block.timestamp;
        rateInfo = _rateInfo;
        token = IERC20(_token);
    }

    // Deposit Liquidity and receive equivalent LP tokens 
    function deposit(uint256 _amount) external {
        _update();
        uint256 totalLiquidity = getTotalLiquidity();
        uint256 sha = _amount;
        if (totalSupply() > 0) {
            sha = _amount * totalSupply() / totalLiquidity;
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount); // transfer erc20 from user to contract
        _mint(msg.sender, sha); // mint lp to user
        emit Deposit(msg.sender, _amount, sha);
    }

    // Withdraw/Burn LP tokens for liquidity
    function withdraw(uint256 _sha) external {
        _update();
        uint256 amt = _sha * getTotalLiquidity() / totalSupply();
        require(balanceOf(msg.sender) >= _sha, "InsufficientBalance");
        require(IERC20(token).balanceOf(address(this)) >= amt, "UtilizationTooHigh");
        _burn(msg.sender, _sha);
        IERC20(token).safeTransfer(msg.sender, amt);
        emit Withdraw(msg.sender, amt, _sha);
    }

    // Borrow against a deposited NFT
    function borrow(uint256 _tokenId, uint256 _amount) external {
        require(loans[_tokenId].isApproved, "Borrow Not Approved");
        require(loans[_tokenId].bor == 0, "Already Borrowed");
        require(loans[_tokenId].borrowLimit >= _amount, "Requested Borrow too High");
        require(msg.sender == loans[_tokenId].tokenOwner, "Not Token Owner");
        
        _update();
        require(IERC20(token).balanceOf(address(this)) >= _amount, "UtilizationTooHigh");
        uint256 bor = _amount * 1e18 / index;
        totalBorrow += bor;

        loans[_tokenId].initiator = msg.sender;
        loans[_tokenId].bor = bor;

        IERC20(token).safeTransfer(msg.sender, _amount);
        emit Borrow(msg.sender, _tokenId, msg.sender, _amount, bor);
    }

    // Repay an outstanding loan. Allows for full or partial repayment
    function repay(uint256 _tokenId, uint256 _bor) external {
        require(loans[_tokenId].bor > 0, "NoLoan");
        require(loans[_tokenId].initiator == msg.sender, "Incorrect Repayer");
        require(_bor <= loans[_tokenId].bor, "Can't Overpay!");

        _update();
        uint256 amt = _bor * index / 1e18;

        if(amt > loans[_tokenId].bor) {
            uint256 excess = amt - loans[_tokenId].bor;
            loans[_tokenId].bor = 0;
        }
        else {
            loans[_tokenId].bor -= amt;
        }

        totalBorrow -= _bor;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amt);
        emit Repay(_tokenId, msg.sender, _bor, amt);
    }
    
    function setLoanData(uint256 _tokenId, address _tokenOwner, bool _isApproved, uint256 _borrowLimit) external {
        //this function should only be allowed to be called by the vault
        loans[_tokenId] = DataTypes.LoanData(_tokenOwner, address(0), _isApproved, _borrowLimit, 0);
    }

    function getLoan(uint256 _tokenId) public view returns(DataTypes.LoanData memory) {
        return loans[_tokenId];
    }

    function getTokenOwner(uint256 _tokenId) external view returns (address) {
        return loans[_tokenId].tokenOwner;
    }

    function getLoanAmount(uint256 _tokenId) external view returns (uint256) {
        return loans[_tokenId].bor;
    }

    function getFullRepayment(uint256 _tokenId) external view returns (uint256) {
        return loans[_tokenId].bor * getUpdatedIndex() / 1e18;
    }
 
    function getUtilization() public view returns (uint256) {
        uint256 totalLiquidity = getTotalLiquidity();
        if (totalLiquidity == 0) return 0;
        return getTotalBorrow() * 1e18 / totalLiquidity;
    }

    function getTotalLiquidity() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this)) + getTotalBorrow();
    }

    function getTotalBorrow() public view returns (uint256) {
        return totalBorrow * index / 1e18;
    }

    function getRedeemable(address user) public view returns(uint256) {
        return balanceOf(user) * getTotalLiquidity() / totalSupply();
    }

    function getUpdatedIndex() public view returns (uint256) {
        uint256 time = block.timestamp - lastUpdate;
        uint256 utilization = getUtilization();
        return index + ((index * _rate(utilization) * time) / 1e18);
    }

    function _update() internal {
        uint256 time = block.timestamp - lastUpdate;
        if (time > 0) {
            uint256 utilization = getUtilization(); // utilization rate in 1e18 notation
            uint256 r = _rate(utilization); // rate
            index += (index * r * time) / 1e18;
            lastUpdate = block.timestamp;
        }
    }

    function _rate(uint256 _amt) internal view returns (uint256) {
        if (_amt <= rateInfo.optimal) {
            return rateInfo.base + (rateInfo.low * _amt / 1e18);
        } else {
            return rateInfo.base + (rateInfo.low * rateInfo.optimal / 1e18) + (rateInfo.high * (_amt - rateInfo.optimal) / 1e18);
        }
    }
}