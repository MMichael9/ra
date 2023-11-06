// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

interface ICurve {
    function add_liquidity(uint[2] calldata uamounts, uint min_mint_amount) external;
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
    function remove_liquidity(uint amount, uint[3] calldata min_amounts) external;
    function calc_token_amount(uint[3] calldata inAmounts, bool deposit) external view returns(uint);
    function balances(int128 i) external view returns(uint);
    function get_virtual_price() external view returns(uint);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
    function coins(uint256 _index) external view returns (address);
}