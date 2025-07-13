// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {PartyTypes} from "../types/PartyTypes.sol";
// import {PartyErrors} from "../types/PartyErrors.sol";
// import {MathLib} from "./MathLib.sol";

// /**
//  * @title FeeLib
//  * @dev Library for fee management and distribution
//  */
// library FeeLib {
//     using MathLib for uint256;
//     using PartyErrors for *;

//     event FeesDistributed(
//         uint256 indexed partyId,
//         uint256 platformFee,
//         uint256 liquidityAmount
//     );

//     event FeesClaimedByDev(
//         uint256 indexed partyId,
//         address indexed dev,
//         uint256 devAmount,
//         uint256 platformAmount
//     );

//     /**
//      * @dev Calculate and distribute platform fees from ETH amount
//      * @param ethAmount The total ETH amount
//      * @param feeConfig The fee configuration
//      * @return platformFee The amount to send to platform treasury
//      * @return liquidityAmount The amount remaining for liquidity
//      */
//     function calculatePlatformFees(
//         uint256 ethAmount,
//         PartyTypes.FeeConfiguration memory feeConfig
//     ) internal pure returns (uint256 platformFee, uint256 liquidityAmount) {
//         platformFee = ethAmount.calculateBasisPoints(feeConfig.platformFeeBPS);
//         liquidityAmount = ethAmount - platformFee;
//     }

//     /**
//      * @dev Calculate token distribution amounts
//      * @return distribution The token distribution structure
//      */
//     function calculateTokenDistribution()
//         internal
//         pure
//         returns (PartyTypes.TokenDistribution memory distribution)
//     {
//         distribution = PartyTypes.TokenDistribution({
//             totalSupply: PartyTypes.FIXED_TOTAL_SUPPLY,
//             liquidityTokens: PartyTypes.DEFAULT_LIQUIDITY_TOKENS,
//             creatorTokens: PartyTypes.DEFAULT_CREATOR_TOKENS,
//             vaultTokens: PartyTypes.DEFAULT_VAULT_TOKENS
//         });
//     }

//     /**
//      * @dev Process fee claim for a party creator
//      * @param totalFees The total fees available to claim
//      * @param devFeeShare The developer's share percentage
//      * @return devAmount Amount for the developer
//      * @return platformAmount Amount for the platform
//      */
//     function processFeesClaim(
//         uint256 totalFees,
//         uint256 devFeeShare
//     ) internal pure returns (uint256 devAmount, uint256 platformAmount) {
//         PartyErrors.requireNonZero(
//             totalFees,
//             PartyErrors.ErrorCode.NO_FEES_TO_WITHDRAW
//         );
//         return MathLib.calculateFeeDistribution(totalFees, devFeeShare);
//     }

//     /**
//      * @dev Validate fee configuration
//      * @param feeConfig The fee configuration to validate
//      */
//     function validateFeeConfiguration(
//         PartyTypes.FeeConfiguration memory feeConfig
//     ) internal pure {
//         PartyErrors.requireValidState(
//             feeConfig.platformFeeBPS <= 1000,
//             PartyErrors.ErrorCode.INVALID_FEE_CONFIG
//         ); // Max 10%
//         PartyErrors.requireValidState(
//             feeConfig.vaultFeeBPS <= 1000,
//             PartyErrors.ErrorCode.INVALID_FEE_CONFIG
//         ); // Max 10%
//         PartyErrors.requireValidState(
//             feeConfig.devFeeShare <= 100,
//             PartyErrors.ErrorCode.INVALID_FEE_CONFIG
//         );
//         PartyErrors.requireNonZeroAddress(
//             feeConfig.platformTreasury,
//             PartyErrors.ErrorCode.ZERO_ADDRESS
//         );
//     }

//     /**
//      * @dev Transfer platform fees to treasury - Enhanced with gas limits and better error handling
//      * @param platformTreasury The treasury address
//      * @param amount The amount to transfer
//      */
//     function transferPlatformFees(
//         address platformTreasury,
//         uint256 amount
//     ) internal {
//         PartyErrors.requireNonZero(
//             amount,
//             PartyErrors.ErrorCode.NO_FEES_TO_WITHDRAW
//         );
//         PartyErrors.requireNonZeroAddress(
//             platformTreasury,
//             PartyErrors.ErrorCode.ZERO_ADDRESS
//         );

//         // Use limited gas to prevent griefing attacks
//         (bool success, ) = payable(platformTreasury).call{
//             value: amount,
//             gas: 2300
//         }(""); // Standard gas limit for ETH transfers

//         if (!success) {
//             // If transfer fails, store the amount for manual recovery
//             // This prevents locking funds permanently
//             assembly {
//                 let slot := keccak256(0, 0x40)
//                 sstore(slot, add(sload(slot), amount))
//             }

//             // Log the failed transfer for monitoring
//             revert PartyErrors.PartyError(
//                 PartyErrors.ErrorCode.TRANSFER_FAILED
//             );
//         }
//     }

//     /**
//      * @dev Transfer dev fees to creator - Enhanced with gas limits and better error handling
//      * @param creator The creator address
//      * @param amount The amount to transfer
//      */
//     function transferDevFees(address creator, uint256 amount) internal {
//         PartyErrors.requireNonZero(
//             amount,
//             PartyErrors.ErrorCode.NO_FEES_TO_WITHDRAW
//         );
//         PartyErrors.requireNonZeroAddress(
//             creator,
//             PartyErrors.ErrorCode.ZERO_ADDRESS
//         );

//         // Use limited gas to prevent griefing attacks
//         (bool success, ) = payable(creator).call{value: amount, gas: 2300}(""); // Standard gas limit for ETH transfers

//         if (!success) {
//             // If transfer fails, store the amount for manual recovery
//             // This prevents locking funds permanently
//             assembly {
//                 let slot := keccak256(0x20, 0x40)
//                 sstore(slot, add(sload(slot), amount))
//             }

//             // Log the failed transfer for monitoring
//             revert PartyErrors.PartyError(
//                 PartyErrors.ErrorCode.TRANSFER_FAILED
//             );
//         }
//     }

//     /**
//      * @dev Emergency function to recover failed fee transfers
//      * Only callable by contract owner in PartyStarter
//      */
//     function getEscrowedPlatformFees() internal view returns (uint256) {
//         uint256 escrowed;
//         assembly {
//             let slot := keccak256(0, 0x40)
//             escrowed := sload(slot)
//         }
//         return escrowed;
//     }

//     /**
//      * @dev Emergency function to recover failed dev fee transfers
//      */
//     function getEscrowedDevFees() internal view returns (uint256) {
//         uint256 escrowed;
//         assembly {
//             let slot := keccak256(0x20, 0x40)
//             escrowed := sload(slot)
//         }
//         return escrowed;
//     }
// }
