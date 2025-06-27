// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

/**
 * @title MockValidHook
 * @dev Simple mock hook for testing that implements minimal EarlySwapLimitHook interface
 * without complex address validation requirements
 */
contract MockValidHook {
    IPoolManager public immutable poolManager;
    address public immutable partyStarter;

    struct SwapLimitConfig {
        uint256 maxSwapCount;
        uint256 maxSwapPercentBPS;
        address tokenAddress;
        uint256 tokenSupply;
        uint256 currentSwapCount;
        bool isActive;
    }

    mapping(PoolId => SwapLimitConfig) public swapConfigs;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
        partyStarter = msg.sender;
    }

    function configureSwapLimits(
        PoolKey calldata poolKey,
        address tokenAddress,
        uint256 maxSwapCount,
        uint256 maxSwapPercentBPS
    ) external {
        // Mock implementation - just store the config
        PoolId poolId = PoolId.wrap(keccak256(abi.encode(poolKey)));
        swapConfigs[poolId] = SwapLimitConfig({
            maxSwapCount: maxSwapCount,
            maxSwapPercentBPS: maxSwapPercentBPS,
            tokenAddress: tokenAddress,
            tokenSupply: 200_000 * 10 ** 18, // Mock total supply
            currentSwapCount: 0,
            isActive: true
        });
    }

    function getMaxSwapAmount(PoolId poolId) external view returns (uint256) {
        SwapLimitConfig storage config = swapConfigs[poolId];
        if (!config.isActive) return type(uint256).max;
        return (config.tokenSupply * config.maxSwapPercentBPS) / 10000;
    }

    function getSwapLimitStatus(
        PoolId poolId
    )
        external
        view
        returns (
            bool isActive,
            uint256 currentSwapCount,
            uint256 maxSwapCount,
            uint256 maxSwapPercentBPS,
            uint256 remainingSwaps
        )
    {
        SwapLimitConfig storage config = swapConfigs[poolId];
        isActive = config.isActive;
        currentSwapCount = config.currentSwapCount;
        maxSwapCount = config.maxSwapCount;
        maxSwapPercentBPS = config.maxSwapPercentBPS;
        remainingSwaps = config.maxSwapCount > config.currentSwapCount
            ? config.maxSwapCount - config.currentSwapCount
            : 0;
    }

    // Mock functions to satisfy EarlySwapLimitHook interface
    function deactivateLimits(PoolId poolId) external {
        SwapLimitConfig storage config = swapConfigs[poolId];
        config.isActive = false;
    }
}
