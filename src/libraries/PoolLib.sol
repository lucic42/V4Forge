// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
// import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
// import {PartyTypes} from "../types/PartyTypes.sol";
// import {MathLib} from "./MathLib.sol";
// import {UniswapV4ERC20} from "../tokens/UniswapV4ERC20.sol";

// /**
//  * @title PoolLib
//  * @dev Library for Uniswap V4 pool management
//  */
// library PoolLib {
//     using PoolIdLibrary for PoolKey;
//     using CurrencyLibrary for Currency;

//     event PoolCreated(
//         uint256 indexed partyId,
//         PoolId indexed poolId,
//         address indexed tokenAddress,
//         uint160 sqrtPriceX96
//     );

//     event LiquidityAdded(
//         uint256 indexed partyId,
//         PoolId indexed poolId,
//         uint256 tokenAmount,
//         uint256 ethAmount
//     );

//     /**
//      * @dev Create a pool key for a token pair with WETH
//      * @param tokenAddress The token address
//      * @param weth The WETH address
//      * @param hooks The hooks contract address
//      * @return poolKey The created pool key
//      */
//     function createPoolKey(
//         address tokenAddress,
//         address weth,
//         address hooks
//     ) internal pure returns (PoolKey memory poolKey) {
//         Currency currency0 = Currency.wrap(
//             tokenAddress < weth ? tokenAddress : weth
//         );
//         Currency currency1 = Currency.wrap(
//             tokenAddress < weth ? weth : tokenAddress
//         );

//         poolKey = PoolKey({
//             currency0: currency0,
//             currency1: currency1,
//             fee: PartyTypes.DEFAULT_FEE,
//             tickSpacing: PartyTypes.DEFAULT_TICK_SPACING,
//             hooks: IHooks(hooks)
//         });
//     }

//     /**
//      * @dev Initialize a Uniswap V4 pool
//      * @param poolManager The pool manager contract
//      * @param poolKey The pool key
//      * @param tokenAmount Amount of tokens for price calculation
//      * @param ethAmount Amount of ETH for price calculation
//      * @return poolId The created pool ID
//      */
//     function initializePool(
//         IPoolManager poolManager,
//         PoolKey memory poolKey,
//         uint256 tokenAmount,
//         uint256 ethAmount
//     ) internal returns (PoolId poolId) {
//         poolId = poolKey.toId();

//         // Calculate initial price
//         bool tokenIsToken0 = Currency.unwrap(poolKey.currency0) <
//             Currency.unwrap(poolKey.currency1);

//         uint160 sqrtPriceX96 = MathLib.calculateSqrtPriceX96(
//             tokenAmount,
//             ethAmount,
//             tokenIsToken0
//         );

//         // Initialize the pool (ignore if already exists)
//         try poolManager.initialize(poolKey, sqrtPriceX96, "") {
//             // Pool initialized successfully
//         } catch {
//             // Pool might already exist, which is fine
//         }

//         return poolId;
//     }

//     /**
//      * @dev Create pool and burn liquidity tokens (simplified approach)
//      * @param poolManager The pool manager contract
//      * @param tokenAddress The token address
//      * @param weth The WETH address
//      * @param hooks The hooks contract address
//      * @param ethAmount Amount of ETH
//      * @param tokenAmount Amount of tokens
//      * @param partyId The party ID for events
//      * @return poolId The created pool ID
//      * @return poolKey The pool key
//      */
//     function createPoolAndBurnLiquidity(
//         IPoolManager poolManager,
//         address tokenAddress,
//         address weth,
//         address hooks,
//         uint256 ethAmount,
//         uint256 tokenAmount,
//         uint256 partyId
//     ) internal returns (PoolId poolId, PoolKey memory poolKey) {
//         // Create pool key
//         poolKey = createPoolKey(tokenAddress, weth, hooks);

//         // Initialize pool
//         poolId = initializePool(poolManager, poolKey, tokenAmount, ethAmount);

//         // Burn the tokens (simplified liquidity approach)
//         UniswapV4ERC20(tokenAddress).burn(address(this), tokenAmount);

//         emit PoolCreated(partyId, poolId, tokenAddress, 0);
//         emit LiquidityAdded(partyId, poolId, tokenAmount, ethAmount);
//     }

//     /**
//      * @dev Validate pool creation parameters
//      * @param tokenAddress The token address
//      * @param weth The WETH address
//      * @param ethAmount The ETH amount
//      * @param tokenAmount The token amount
//      */
//     function validatePoolParameters(
//         address tokenAddress,
//         address weth,
//         uint256 ethAmount,
//         uint256 tokenAmount
//     ) internal pure {
//         require(tokenAddress != address(0), "Invalid token address");
//         require(weth != address(0), "Invalid WETH address");
//         require(tokenAddress != weth, "Token cannot be WETH");
//         require(ethAmount > 0, "ETH amount must be greater than 0");
//         require(tokenAmount > 0, "Token amount must be greater than 0");
//     }

//     /**
//      * @dev Create LP position data structure
//      * @param poolKey The pool key
//      * @param poolId The pool ID
//      * @param tokenAddress The token address
//      * @return position The LP position structure
//      */
//     function createLPPosition(
//         PoolKey memory poolKey,
//         PoolId poolId,
//         address tokenAddress
//     ) internal pure returns (PartyTypes.LPPosition memory position) {
//         position = PartyTypes.LPPosition({
//             poolKey: poolKey,
//             poolId: poolId,
//             tokenAddress: tokenAddress,
//             tokenId: 0, // Would be set by actual LP position NFT
//             feesClaimable: true
//         });
//     }
// }
