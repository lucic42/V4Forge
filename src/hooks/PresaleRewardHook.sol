// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {BaseHook} from "v4-periphery/BaseHook.sol";
// import {Hooks} from "v4-core/src/libraries/Hooks.sol";
// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
// import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
// import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
// import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";

// interface IPresaleVenue {
//     function notifySwap(
//         address user,
//         address tokenIn,
//         address tokenOut,
//         uint256 amountIn,
//         uint256 amountOut,
//         bool isExactInput
//     ) external;

//     function isOriginalContributor(address user) external view returns (bool);
//     function getOriginalTokenAddress() external view returns (address);
// }

// /**
//  * @title PresaleRewardHook
//  * @dev Uniswap V4 hook that tracks swaps involving presale tokens and notifies the venue
//  * for proper reward calculation when original contributors trade through the pool
//  */
// contract PresaleRewardHook is BaseHook {
//     using PoolIdLibrary for PoolKey;
//     using CurrencyLibrary for Currency;

//     // State variables
//     mapping(PoolId => address) public poolToVenue; // Pool ID to venue contract mapping
//     mapping(address => PoolId) public venueToPool; // Venue contract to pool ID mapping

//     // Events
//     event PresalePoolRegistered(
//         PoolId indexed poolId,
//         address indexed venue,
//         address indexed token
//     );
//     event PresaleSwapTracked(
//         address indexed user,
//         address indexed venue,
//         bool isSelling,
//         uint256 tokenAmount,
//         uint256 ethAmount
//     );

//     constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

//     /**
//      * @dev Register a presale venue with its pool for tracking
//      */
//     function registerPresalePool(PoolKey calldata key, address venue) external {
//         PoolId poolId = key.toId();

//         // Verify this is a valid presale venue
//         IPresaleVenue presaleVenue = IPresaleVenue(venue);
//         address tokenAddress = presaleVenue.getOriginalTokenAddress();

//         // Verify the pool contains the presale token
//         require(
//             Currency.unwrap(key.currency0) == tokenAddress ||
//                 Currency.unwrap(key.currency1) == tokenAddress,
//             "Pool does not contain presale token"
//         );

//         poolToVenue[poolId] = venue;
//         venueToPool[venue] = poolId;

//         emit PresalePoolRegistered(poolId, venue, tokenAddress);
//     }

//     /**
//      * @dev Get hook permissions - we need beforeSwap and afterSwap
//      */
//     function getHookPermissions()
//         public
//         pure
//         override
//         returns (Hooks.Permissions memory)
//     {
//         return
//             Hooks.Permissions({
//                 beforeInitialize: false,
//                 afterInitialize: false,
//                 beforeAddLiquidity: false,
//                 afterAddLiquidity: false,
//                 beforeRemoveLiquidity: false,
//                 afterRemoveLiquidity: false,
//                 beforeSwap: true, // Track swaps before they happen
//                 afterSwap: true, // Update venue after swap completes
//                 beforeDonate: false,
//                 afterDonate: false,
//                 beforeSwapReturnDelta: false,
//                 afterSwapReturnDelta: false,
//                 afterAddLiquidityReturnDelta: false,
//                 afterRemoveLiquidityReturnDelta: false
//             });
//     }

//     /**
//      * @dev Before swap hook - prepare for tracking
//      */
//     function beforeSwap(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params,
//         bytes calldata hookData
//     ) external override returns (bytes4, BeforeSwapDelta, uint24) {
//         PoolId poolId = key.toId();
//         address venue = poolToVenue[poolId];

//         if (venue != address(0)) {
//             // Check if this is an original contributor
//             IPresaleVenue presaleVenue = IPresaleVenue(venue);
//             if (presaleVenue.isOriginalContributor(sender)) {
//                 // Store swap data for afterSwap processing
//                 _storeSwapData(poolId, sender, key, params);
//             }
//         }

//         return (
//             BaseHook.beforeSwap.selector,
//             BeforeSwapDeltaLibrary.ZERO_DELTA,
//             0
//         );
//     }

//     /**
//      * @dev After swap hook - notify venue of completed swap
//      */
//     function afterSwap(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params,
//         BalanceDelta delta,
//         bytes calldata hookData
//     ) external override returns (bytes4, int128) {
//         PoolId poolId = key.toId();
//         address venue = poolToVenue[poolId];

//         if (venue != address(0)) {
//             IPresaleVenue presaleVenue = IPresaleVenue(venue);

//             // Only track swaps from original contributors
//             if (presaleVenue.isOriginalContributor(sender)) {
//                 _processSwapForRewards(sender, key, params, delta, venue);
//             }
//         }

//         return (BaseHook.afterSwap.selector, 0);
//     }

//     /**
//      * @dev Store swap data for processing in afterSwap
//      */
//     function _storeSwapData(
//         PoolId poolId,
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params
//     ) internal {
//         // Store relevant swap data in a mapping for afterSwap processing
//         // This is a simplified version - in practice you'd want more sophisticated storage
//     }

//     /**
//      * @dev Process the completed swap and notify the venue
//      */
//     function _processSwapForRewards(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params,
//         BalanceDelta delta,
//         address venue
//     ) internal {
//         IPresaleVenue presaleVenue = IPresaleVenue(venue);
//         address tokenAddress = presaleVenue.getOriginalTokenAddress();

//         // Determine which currency is the presale token
//         bool token0IsPresaleToken = Currency.unwrap(key.currency0) ==
//             tokenAddress;
//         bool token1IsPresaleToken = Currency.unwrap(key.currency1) ==
//             tokenAddress;

//         if (!token0IsPresaleToken && !token1IsPresaleToken) return;

//         // Extract swap amounts from delta
//         int128 amount0 = delta.amount0();
//         int128 amount1 = delta.amount1();

//         // Determine if user is buying or selling presale tokens
//         bool isSelling;
//         uint256 tokenAmount;
//         uint256 ethAmount;

//         if (token0IsPresaleToken) {
//             // Token is currency0
//             isSelling = amount0 > 0; // User is giving tokens (selling)
//             tokenAmount = uint256(amount0 > 0 ? amount0 : -amount0);
//             ethAmount = uint256(amount1 > 0 ? amount1 : -amount1);
//         } else {
//             // Token is currency1
//             isSelling = amount1 > 0; // User is giving tokens (selling)
//             tokenAmount = uint256(amount1 > 0 ? amount1 : -amount1);
//             ethAmount = uint256(amount0 > 0 ? amount0 : -amount0);
//         }

//         // Notify the venue about the swap
//         address tokenIn = isSelling
//             ? tokenAddress
//             : Currency.unwrap(
//                 key.currency0 == Currency.wrap(tokenAddress)
//                     ? key.currency1
//                     : key.currency0
//             );
//         address tokenOut = isSelling
//             ? Currency.unwrap(
//                 key.currency0 == Currency.wrap(tokenAddress)
//                     ? key.currency1
//                     : key.currency0
//             )
//             : tokenAddress;

//         presaleVenue.notifySwap(
//             sender,
//             tokenIn,
//             tokenOut,
//             isSelling ? tokenAmount : ethAmount,
//             isSelling ? ethAmount : tokenAmount,
//             true // For simplicity, assume exact input
//         );

//         emit PresaleSwapTracked(
//             sender,
//             venue,
//             isSelling,
//             tokenAmount,
//             ethAmount
//         );
//     }

//     /**
//      * @dev Get venue address for a given pool
//      */
//     function getVenueForPool(PoolId poolId) external view returns (address) {
//         return poolToVenue[poolId];
//     }

//     /**
//      * @dev Get pool ID for a given venue
//      */
//     function getPoolForVenue(address venue) external view returns (PoolId) {
//         return venueToPool[venue];
//     }

//     /**
//      * @dev Check if a pool is registered for presale tracking
//      */
//     function isPresalePool(PoolId poolId) external view returns (bool) {
//         return poolToVenue[poolId] != address(0);
//     }
// }
