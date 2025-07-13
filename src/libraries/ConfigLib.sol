// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {PartyTypes} from "../types/PartyTypes.sol";

// /**
//  * @title ConfigLib
//  * @dev Library for managing system configuration and defaults
//  */
// library ConfigLib {
//     event ConfigurationUpdated(string indexed configType, bytes data);

//     /**
//      * @dev Create default fee configuration
//      * @param platformTreasury The platform treasury address
//      * @return feeConfig The default fee configuration
//      */
//     function createDefaultFeeConfiguration(
//         address platformTreasury
//     ) internal pure returns (PartyTypes.FeeConfiguration memory feeConfig) {
//         feeConfig = PartyTypes.FeeConfiguration({
//             platformFeeBPS: PartyTypes.PLATFORM_FEE_BPS,
//             vaultFeeBPS: PartyTypes.VAULT_FEE_BPS,
//             devFeeShare: PartyTypes.DEV_FEE_SHARE,
//             platformTreasury: platformTreasury
//         });
//     }

//     /**
//      * @dev Validate swap limit configuration
//      * @param maxSwapCount The maximum number of swaps to limit
//      * @param maxSwapPercentBPS The maximum swap percentage in basis points
//      */
//     function validateSwapLimitConfig(
//         uint256 maxSwapCount,
//         uint256 maxSwapPercentBPS
//     ) internal pure {
//         require(maxSwapCount > 0, "Invalid max swap count");
//         require(maxSwapPercentBPS <= 1000, "Invalid max swap percent"); // Max 10%
//     }

//     /**
//      * @dev Get default token distribution configuration
//      * @return distribution The default token distribution
//      */
//     function getDefaultTokenDistribution()
//         internal
//         pure
//         returns (PartyTypes.TokenDistribution memory distribution)
//     {
//         distribution = PartyTypes.TokenDistribution({
//             totalSupply: PartyTypes.DEFAULT_TOTAL_SUPPLY,
//             liquidityTokens: PartyTypes.DEFAULT_LIQUIDITY_TOKENS,
//             creatorTokens: PartyTypes.DEFAULT_CREATOR_TOKENS,
//             vaultTokens: PartyTypes.DEFAULT_VAULT_TOKENS
//         });
//     }

//     /**
//      * @dev Validate system addresses
//      * @param poolManager The pool manager address
//      * @param vault The vault address
//      * @param weth The WETH address
//      * @param treasury The treasury address
//      */
//     function validateSystemAddresses(
//         address poolManager,
//         address vault,
//         address weth,
//         address treasury
//     ) internal pure {
//         require(poolManager != address(0), "Invalid pool manager");
//         require(vault != address(0), "Invalid vault");
//         require(weth != address(0), "Invalid WETH address");
//         require(treasury != address(0), "Invalid treasury address");
//     }

//     /**
//      * @dev Calculate system limits
//      * @param value The base value
//      * @return maxValue The maximum allowed value (110% of base)
//      * @return minValue The minimum allowed value (10% of base)
//      */
//     function calculateSystemLimits(
//         uint256 value
//     ) internal pure returns (uint256 maxValue, uint256 minValue) {
//         maxValue = (value * 110) / 100; // 110% of base
//         minValue = (value * 10) / 100; // 10% of base
//     }
// }
// // 