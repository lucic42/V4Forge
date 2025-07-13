// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {PoolId} from "v4-core/src/types/PoolId.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";

// import {PartyTypes} from "../types/PartyTypes.sol";
// import {PartyErrors} from "../types/PartyErrors.sol";
// import {TokenLib} from "./TokenLib.sol";
// import {PoolLib} from "./PoolLib.sol";
// import {FeeLib} from "./FeeLib.sol";
// import {UniswapV4ERC20} from "../tokens/UniswapV4ERC20.sol";
// import {PartyVault} from "../vault/PartyVault.sol";
// import {EarlySwapLimitHook} from "../hooks/EarlySwapLimitHook.sol";

// /**
//  * @title LaunchLib
//  * @dev Library for handling party launch logic
//  * Extracted to reduce main contract size
//  */
// library LaunchLib {
//     using PartyErrors for *;

//     event PartySystemTokenLaunched(
//         uint256 indexed partyId,
//         address indexed tokenAddress,
//         address indexed creator,
//         string name,
//         string symbol,
//         PoolId poolId,
//         uint256 totalLiquidity,
//         uint256 timestamp
//     );

//     event PartyLaunched(
//         uint256 indexed partyId,
//         address indexed tokenAddress,
//         PoolId indexed poolId,
//         uint256 totalLiquidity
//     );

//     /**
//      * @dev Execute party launch with all required steps
//      */
//     function executePartyLaunch(
//         uint256 partyId,
//         uint256 ethAmount,
//         PartyTypes.Party storage party,
//         PartyTypes.FeeConfiguration memory feeConfig,
//         PartyVault partyVault,
//         IPoolManager poolManager,
//         address weth,
//         EarlySwapLimitHook swapLimitHook,
//         uint256 defaultMaxSwapCount,
//         uint256 defaultMaxSwapPercentBPS
//     ) external returns (PartyTypes.LPPosition memory lpPosition) {
//         // Validate metadata
//         TokenLib.validateTokenMetadata(party.metadata);

//         // Create token
//         UniswapV4ERC20 token = TokenLib.createToken(partyId, party.metadata);

//         // Mint and distribute tokens
//         PartyTypes.TokenDistribution memory distribution = TokenLib
//             .mintAndDistributeTokens(token, partyId, party.creator, partyVault);

//         // Calculate and transfer platform fees
//         (uint256 platformFee, uint256 liquidityAmount) = FeeLib
//             .calculatePlatformFees(ethAmount, feeConfig);

//         FeeLib.transferPlatformFees(feeConfig.platformTreasury, platformFee);

//         // Create pool and position
//         (PoolId poolId, PoolKey memory poolKey) = PoolLib
//             .createPoolAndBurnLiquidity(
//                 poolManager,
//                 address(token),
//                 weth,
//                 address(swapLimitHook),
//                 liquidityAmount,
//                 distribution.liquidityTokens,
//                 partyId
//             );

//         // Configure swap limits
//         swapLimitHook.configureSwapLimits(
//             poolKey,
//             address(token),
//             defaultMaxSwapCount,
//             defaultMaxSwapPercentBPS
//         );

//         // Update party state
//         party.tokenAddress = address(token);
//         party.poolId = poolId;
//         party.totalLiquidity = liquidityAmount;
//         party.launched = true;

//         // Create LP position
//         lpPosition = PoolLib.createLPPosition(poolKey, poolId, address(token));

//         // Emit events
//         emit PartySystemTokenLaunched(
//             partyId,
//             address(token),
//             party.creator,
//             party.metadata.name,
//             party.metadata.symbol,
//             poolId,
//             liquidityAmount,
//             block.timestamp
//         );

//         emit PartyLaunched(partyId, address(token), poolId, liquidityAmount);
//     }
// }
