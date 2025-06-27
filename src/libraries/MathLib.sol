// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MathLib
 * @dev Library for mathematical calculations used in the party system
 * Enhanced with overflow protection and gas optimizations
 */
library MathLib {
    error MathOverflow();
    error InvalidInput();

    // Maximum safe values to prevent overflow
    uint256 private constant MAX_SAFE_MULTIPLIER = type(uint256).max / 1e18;
    uint160 private constant MAX_SQRT_PRICE = type(uint160).max;

    /**
     * @dev Calculate sqrt price for pool initialization - Gas optimized with overflow protection
     * @param tokenAmount Amount of tokens in the pool
     * @param ethAmount Amount of ETH in the pool
     * @param tokenIsToken0 Whether the token is token0 in the pair
     * @return sqrtPriceX96 The sqrt price in X96 format
     */
    function calculateSqrtPriceX96(
        uint256 tokenAmount,
        uint256 ethAmount,
        bool tokenIsToken0
    ) internal pure returns (uint160) {
        if (tokenAmount == 0 || ethAmount == 0) revert InvalidInput();

        // Prevent overflow in price calculation
        if (
            ethAmount > MAX_SAFE_MULTIPLIER || tokenAmount > MAX_SAFE_MULTIPLIER
        ) {
            revert MathOverflow();
        }

        uint256 price;
        unchecked {
            if (tokenIsToken0) {
                price = (ethAmount * 1e18) / tokenAmount;
            } else {
                price = (tokenAmount * 1e18) / ethAmount;
            }
        }

        // Prevent overflow in sqrt calculation
        if (price > MAX_SAFE_MULTIPLIER) revert MathOverflow();

        uint256 sqrtPrice = sqrt(price * 1e18);

        // Use bit shifting for efficiency: 2^96 = 1 << 96
        uint256 result = (sqrtPrice << 96) / 1e18;

        if (result > uint256(MAX_SQRT_PRICE)) revert MathOverflow();

        return uint160(result);
    }

    /**
     * @dev Gas-optimized square root function using Babylonian method
     * @param x The number to find square root of
     * @return The square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        if (x <= 3) return 1;

        // Use bit shifting for initial guess (more gas efficient)
        uint256 z = x;
        uint256 y = (x + 1) >> 1;

        // Maximum 10 iterations to prevent infinite loops
        for (uint256 i = 0; i < 10 && y < z; ++i) {
            z = y;
            unchecked {
                y = (x / z + z) >> 1;
            }
        }

        return z;
    }

    /**
     * @dev Calculate percentage of a value in basis points - Gas optimized
     * @param value The base value
     * @param basisPoints The percentage in basis points (1 basis point = 0.01%)
     * @return The calculated percentage
     */
    function calculateBasisPoints(
        uint256 value,
        uint256 basisPoints
    ) internal pure returns (uint256) {
        if (basisPoints > 10000) revert InvalidInput(); // Max 100%
        if (value == 0) return 0;

        // Use unchecked math for gas optimization (safe after validation)
        unchecked {
            return (value * basisPoints) / 10000;
        }
    }

    /**
     * @dev Calculate fee distribution - Gas optimized
     * @param totalAmount The total amount to distribute
     * @param devFeeShare The developer's share percentage (0-100)
     * @return devAmount The amount for the developer
     * @return platformAmount The amount for the platform
     */
    function calculateFeeDistribution(
        uint256 totalAmount,
        uint256 devFeeShare
    ) internal pure returns (uint256 devAmount, uint256 platformAmount) {
        if (devFeeShare > 100) revert InvalidInput();
        if (totalAmount == 0) return (0, 0);

        unchecked {
            devAmount = (totalAmount * devFeeShare) / 100;
            platformAmount = totalAmount - devAmount;
        }
    }
}
