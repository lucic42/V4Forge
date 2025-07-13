// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap V3 pool facilitates swapping and providing liquidity between two assets
interface IUniswapV3Pool {
    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);
}
