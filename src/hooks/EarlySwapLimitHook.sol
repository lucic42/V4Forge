// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {BaseHook} from "v4-periphery/BaseHook.sol";
// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {Hooks} from "v4-core/src/libraries/Hooks.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
// import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
// import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {Owned} from "solmate/auth/Owned.sol";

// /**
//  * @title EarlySwapLimitHook
//  * @dev Hook that limits the size of the first X swaps to Y percent of token supply
//  * Prevents manipulation during initial trading periods by enforcing swap size limits atomically
//  */
// contract EarlySwapLimitHook is BaseHook, Owned {
//     using PoolIdLibrary for PoolKey;
//     using CurrencyLibrary for Currency;

//     error SwapAmountExceedsLimit(uint256 requestedAmount, uint256 maxAllowed);
//     error TokenNotFound();
//     error InvalidConfiguration();

//     struct SwapLimitConfig {
//         uint256 maxSwapCount; // Number of swaps to limit (X)
//         uint256 maxSwapPercentBPS; // Max percent of supply per swap in basis points (Y * 100)
//         address tokenAddress; // Address of the token being limited
//         uint256 tokenSupply; // Total supply cached at configuration time
//         uint256 currentSwapCount; // Current number of swaps executed
//         bool isActive; // Whether limits are currently active
//     }

//     // PoolId => SwapLimitConfig
//     mapping(PoolId => SwapLimitConfig) public swapConfigs;

//     // Only authorized party starter can configure limits
//     address public immutable partyStarter;

//     event SwapLimitConfigured(
//         PoolId indexed poolId,
//         address indexed tokenAddress,
//         uint256 maxSwapCount,
//         uint256 maxSwapPercentBPS,
//         uint256 tokenSupply
//     );

//     event SwapExecutedWithLimit(
//         PoolId indexed poolId,
//         uint256 swapNumber,
//         uint256 swapAmount,
//         uint256 maxAllowed
//     );

//     event SwapLimitsDeactivated(PoolId indexed poolId);

//     constructor(
//         IPoolManager _poolManager,
//         address _partyStarter
//     ) BaseHook(_poolManager) Owned(msg.sender) {
//         partyStarter = _partyStarter;
//     }

//     modifier onlyPartyStarter() {
//         require(msg.sender == partyStarter, "Only PartyStarter can configure");
//         _;
//     }

//     /**
//      * @dev Configure swap limits for a pool
//      * @param poolKey The pool key to configure limits for
//      * @param tokenAddress The token address being limited
//      * @param maxSwapCount Number of swaps to apply limits to (X)
//      * @param maxSwapPercentBPS Max swap size as basis points of supply (Y * 100)
//      */
//     function configureSwapLimits(
//         PoolKey calldata poolKey,
//         address tokenAddress,
//         uint256 maxSwapCount,
//         uint256 maxSwapPercentBPS
//     ) external onlyPartyStarter {
//         require(maxSwapCount > 0, "maxSwapCount must be > 0");
//         require(
//             maxSwapPercentBPS > 0 && maxSwapPercentBPS <= 10000,
//             "Invalid percentage"
//         );
//         require(tokenAddress != address(0), "Invalid token address");

//         PoolId poolId = poolKey.toId();

//         // Get token supply
//         uint256 tokenSupply = IERC20(tokenAddress).totalSupply();
//         require(tokenSupply > 0, "Token supply must be > 0");

//         swapConfigs[poolId] = SwapLimitConfig({
//             maxSwapCount: maxSwapCount,
//             maxSwapPercentBPS: maxSwapPercentBPS,
//             tokenAddress: tokenAddress,
//             tokenSupply: tokenSupply,
//             currentSwapCount: 0,
//             isActive: true
//         });

//         emit SwapLimitConfigured(
//             poolId,
//             tokenAddress,
//             maxSwapCount,
//             maxSwapPercentBPS,
//             tokenSupply
//         );
//     }

//     /**
//      * @dev Get the hook permissions
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
//                 beforeRemoveLiquidity: false,
//                 afterAddLiquidity: false,
//                 afterRemoveLiquidity: false,
//                 beforeSwap: true,
//                 afterSwap: false,
//                 beforeDonate: false,
//                 afterDonate: false,
//                 beforeSwapReturnDelta: false,
//                 afterSwapReturnDelta: false,
//                 afterAddLiquidityReturnDelta: false,
//                 afterRemoveLiquidityReturnDelta: false
//             });
//     }

//     /**
//      * @dev beforeSwap hook to enforce swap size limits
//      */
//     function beforeSwap(
//         address sender,
//         PoolKey calldata key,
//         IPoolManager.SwapParams calldata params,
//         bytes calldata hookData
//     )
//         external
//         override
//         onlyByManager
//         returns (bytes4, BeforeSwapDelta, uint24)
//     {
//         PoolId poolId = key.toId();
//         SwapLimitConfig storage config = swapConfigs[poolId];

//         // If no limits configured or limits no longer active, allow swap to proceed
//         if (
//             !config.isActive || config.currentSwapCount >= config.maxSwapCount
//         ) {
//             return (
//                 BaseHook.beforeSwap.selector,
//                 BeforeSwapDeltaLibrary.ZERO_DELTA,
//                 0
//             );
//         }

//         // Determine which currency is the limited token
//         bool isToken0Limited = Currency.unwrap(key.currency0) ==
//             config.tokenAddress;
//         bool isToken1Limited = Currency.unwrap(key.currency1) ==
//             config.tokenAddress;

//         if (!isToken0Limited && !isToken1Limited) {
//             // Token not found in this pool, allow swap
//             return (
//                 BaseHook.beforeSwap.selector,
//                 BeforeSwapDeltaLibrary.ZERO_DELTA,
//                 0
//             );
//         }

//         // Calculate max allowed swap amount (percentage of total supply)
//         uint256 maxSwapAmount = (config.tokenSupply *
//             config.maxSwapPercentBPS) / 10000;

//         // Get the absolute amount being swapped
//         uint256 swapAmount = uint256(
//             params.amountSpecified < 0
//                 ? -params.amountSpecified
//                 : params.amountSpecified
//         );

//         // Check if this swap involves the limited token
//         bool swapInvolvesLimitedToken = false;
//         if (isToken0Limited && params.zeroForOne) {
//             // Swapping token0 (limited token) for token1
//             swapInvolvesLimitedToken = true;
//         } else if (isToken1Limited && !params.zeroForOne) {
//             // Swapping token1 (limited token) for token0
//             swapInvolvesLimitedToken = true;
//         }

//         // If the swap doesn't involve the limited token as input, allow it
//         if (!swapInvolvesLimitedToken) {
//             return (
//                 BaseHook.beforeSwap.selector,
//                 BeforeSwapDeltaLibrary.ZERO_DELTA,
//                 0
//             );
//         }

//         // Enforce the limit
//         if (swapAmount > maxSwapAmount) {
//             revert SwapAmountExceedsLimit(swapAmount, maxSwapAmount);
//         }

//         // Increment swap count (atomic operation)
//         config.currentSwapCount++;

//         emit SwapExecutedWithLimit(
//             poolId,
//             config.currentSwapCount,
//             swapAmount,
//             maxSwapAmount
//         );

//         // Deactivate limits if we've reached the max count
//         if (config.currentSwapCount >= config.maxSwapCount) {
//             config.isActive = false;
//             emit SwapLimitsDeactivated(poolId);
//         }

//         return (
//             BaseHook.beforeSwap.selector,
//             BeforeSwapDeltaLibrary.ZERO_DELTA,
//             0
//         );
//     }

//     /**
//      * @dev Emergency function to deactivate limits (only owner)
//      */
//     function deactivateLimits(PoolId poolId) external onlyOwner {
//         SwapLimitConfig storage config = swapConfigs[poolId];
//         config.isActive = false;
//         emit SwapLimitsDeactivated(poolId);
//     }

//     /**
//      * @dev Get swap limit status for a pool
//      */
//     function getSwapLimitStatus(
//         PoolId poolId
//     )
//         external
//         view
//         returns (
//             bool isActive,
//             uint256 currentSwapCount,
//             uint256 maxSwapCount,
//             uint256 maxSwapPercentBPS,
//             uint256 remainingSwaps
//         )
//     {
//         SwapLimitConfig storage config = swapConfigs[poolId];
//         isActive = config.isActive;
//         currentSwapCount = config.currentSwapCount;
//         maxSwapCount = config.maxSwapCount;
//         maxSwapPercentBPS = config.maxSwapPercentBPS;
//         remainingSwaps = config.maxSwapCount > config.currentSwapCount
//             ? config.maxSwapCount - config.currentSwapCount
//             : 0;
//     }

//     /**
//      * @dev Get maximum allowed swap amount for a pool
//      */
//     function getMaxSwapAmount(PoolId poolId) external view returns (uint256) {
//         SwapLimitConfig storage config = swapConfigs[poolId];
//         if (!config.isActive) return type(uint256).max;
//         return (config.tokenSupply * config.maxSwapPercentBPS) / 10000;
//     }
// }
