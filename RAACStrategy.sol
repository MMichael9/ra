// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Test contract that integrates with Curve and Convex pools
// Using borrowed funds, deposit to Curve pool, Boost in Convex pool and collect rewards

import "./interfaces/ICurve.sol";
import "./interfaces/IConvex.sol";
import "./interfaces/IConvexRewards.sol";
import "./interfaces/IRAACLendingPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RAACStrategy is Ownable {
    using SafeERC20 for IERC20;

    ICurve public curveInterface; 
    IERC20 public tokenInterface;
    IConvex public convexInterface;
    uint256 public convexPoolId;
    IConvexRewards public convexRewardsInterface;
    IRAACLendingPool public lendingPoolInterface;
    uint256 public tokenId;

    address public crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public crv = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public cvx = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;

    address[] public TOKENS = [usdc, crvUSD];

    event InitiateLoan(address indexed operator, address indexed strategy, uint256 indexed tokenId, uint256 amount);
    event AddToCurve(address indexed operator, address indexed strategy, uint256 indexed tokenId, uint256[2] amounts);
    event BoostToConvex(address indexed operator, address indexed strategy, uint256 indexed tokenId, uint256 amount);
    event ClaimFromConvex(address indexed operator, address indexed strategy, uint256 indexed tokenId, address convexAddress);
    event ClaimFromStrategy(address indexed operator, uint256 indexed tokenId, uint256 crv, uint256 cvx);
    event ConvexWithdraw(address indexed operator, address indexed strategy, uint256 tokenId, uint256 amount);
    event CurveWithdraw(address indexed operator, address indexed strategy, uint256 tokenId, uint256 amount);
    event RepayLendPool(address indexed operator, address indexed strategy, uint256 tokenId, uint256 availAmount, uint256 borrowAmount);

    constructor(
        uint256 _tokenId,
        address _crvPool,
        address _crvLPToken,
        address _cvxPool,
        uint256 _cvxPoolId,
        address _cvxReward,
        address _lendingPool
    ) {
        tokenId = _tokenId;
        curveInterface = ICurve(_crvPool);
        tokenInterface = IERC20(_crvLPToken);
        convexInterface = IConvex(_cvxPool);
        convexPoolId = _cvxPoolId;
        convexRewardsInterface = IConvexRewards(_cvxReward);
        lendingPoolInterface = IRAACLendingPool(_lendingPool);
    }

    function borrow(uint256 _amount) external onlyOwner {
        lendingPoolInterface.borrow(tokenId, _amount);
        
        emit InitiateLoan(msg.sender, address(this), tokenId, _amount);
    }

    // Add to curve liquidity pool
    function add() external onlyOwner {
        // get amounts to send to curve pool
        uint256[2] memory amounts = [uint256(0),0];

        for(uint256 i=0;i<TOKENS.length;i++){
            amounts[i] = IERC20(TOKENS[i]).balanceOf(address(this));

            if(amounts[i] > 0)
                _safeApprove(TOKENS[i], address(curveInterface), amounts[i]); // approve curve to spend tokens
        }

        // interact with curve pool
        curveInterface.add_liquidity(amounts, uint256(1));

        emit AddToCurve(msg.sender, address(this), tokenId, amounts);
    }

    // Boost crv lp in convex pool
    function boost() external onlyOwner {
        // get amount of CRV LP Tokens to send to convex
        uint256 lpTokenAmount = tokenInterface.balanceOf(address(this));
        _safeApprove(address(tokenInterface), address(convexInterface), lpTokenAmount);

        bool success = convexInterface.deposit(convexPoolId, lpTokenAmount, true);
        require(success);

        emit BoostToConvex(msg.sender, address(this), tokenId, lpTokenAmount);
    }

    // Claim CRV and CVX rewards in convex
    function claim() external onlyOwner {
        bool success = convexRewardsInterface.getReward();
        require(success);

        emit ClaimFromConvex(msg.sender, address(this), tokenId, address(convexRewardsInterface));
    }

    function claimDirect() external onlyOwner {
        uint256 crvAmt = IERC20(crv).balanceOf(address(this));
        uint256 cvxAmt = IERC20(cvx).balanceOf(address(this));

        IERC20(crv).safeTransfer(msg.sender, crvAmt);
        IERC20(cvx).safeTransfer(msg.sender, cvxAmt);
        emit ClaimFromStrategy(msg.sender, tokenId, crvAmt, cvxAmt);
    }

    // Withdraw CVX LP tokens and unwrap to CRV LP Tokens
    function withdraw(uint256 _amount) external onlyOwner {
        bool success = convexRewardsInterface.withdrawAndUnwrap(_amount, false);
        require(success);

        emit ConvexWithdraw(msg.sender, address(this), tokenId, _amount);
    }

    // Remove curve lp tokens from pool and get back crvusd
    function remove(uint256 _amount) external onlyOwner {
        curveInterface.remove_liquidity_one_coin(_amount, 1, 1);

        emit CurveWithdraw(msg.sender, address(this), tokenId, _amount);
    }

    // Repay Lend Pool 
    function repay() external onlyOwner {
        uint256 amount = IERC20(crvUSD).balanceOf(address(this));
        uint256 bor = lendingPoolInterface.getLoanAmount(tokenId);

        _safeApprove(crvUSD, address(lendingPoolInterface), amount);
        lendingPoolInterface.repay(tokenId, amount);

        emit RepayLendPool(msg.sender, address(this), tokenId, amount, bor);
    }

    function getConvexBalance() public view returns(uint256) {
        return convexRewardsInterface.balanceOf(address(this));
    }

    function getEarned() public view returns(uint256) {
        return convexRewardsInterface.earned(address(this));
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", spender, amount);
        (bool success, bytes memory returnData) = token.call(data);
        require(success && (returnData.length == 0 || abi.decode(returnData, (bool))), "Safe approve failed");
    }
}