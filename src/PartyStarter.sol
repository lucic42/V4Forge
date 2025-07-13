// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {PoolId} from "v4-core/src/types/PoolId.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// import {Owned} from "solmate/auth/Owned.sol";
// import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// // Import our types and interfaces
// import {PartyTypes} from "./types/PartyTypes.sol";
// import {PartyErrors} from "./types/PartyErrors.sol";
// import {IPartyStarter} from "./interfaces/IPartyStarter.sol";

// // Import our libraries
// import {PartyLib} from "./libraries/PartyLib.sol";
// import {LaunchLib} from "./libraries/LaunchLib.sol";
// import {TokenLib} from "./libraries/TokenLib.sol";
// import {PoolLib} from "./libraries/PoolLib.sol";
// import {FeeLib} from "./libraries/FeeLib.sol";
// import {ConfigLib} from "./libraries/ConfigLib.sol";

// // Import contracts
// import {UniswapV4ERC20} from "./tokens/UniswapV4ERC20.sol";
// import {PartyVault} from "./vault/PartyVault.sol";
// import {PartyVenue} from "./venue/PartyVenue.sol";
// import {EarlySwapLimitHook} from "./hooks/EarlySwapLimitHook.sol";

// /**
//  * @title PartyStarter
//  * @dev Main contract for launching tokens with different party types
//  * Refactored for better modularity and code organization
//  */
// contract PartyStarter is Owned, ReentrancyGuard, IPartyStarter {
//     using PartyErrors for *;

//     // Immutable dependencies
//     IPoolManager public immutable poolManager;
//     PartyVault public immutable partyVault;
//     EarlySwapLimitHook public immutable swapLimitHook;
//     address public immutable weth;

//     // Configuration
//     PartyTypes.FeeConfiguration public feeConfig;
//     uint256 public defaultMaxSwapCount = 50;
//     uint256 public defaultMaxSwapPercentBPS = 200; // 2%

//     // State
//     uint256 public partyCounter;
//     mapping(uint256 => PartyTypes.Party) public parties;
//     mapping(address => uint256[]) public userParties;
//     mapping(uint256 => PartyTypes.LPPosition) public lpPositions;
//     mapping(address => bool) public canClaimFees;

//     constructor(
//         IPoolManager _poolManager,
//         PartyVault _partyVault,
//         address _weth,
//         address _platformTreasury
//     ) Owned(msg.sender) {
//         // Validate system addresses
//         ConfigLib.validateSystemAddresses(
//             address(_poolManager),
//             address(_partyVault),
//             _weth,
//             _platformTreasury
//         );

//         poolManager = _poolManager;
//         partyVault = _partyVault;
//         weth = _weth;

//         // Initialize fee configuration using library
//         feeConfig = ConfigLib.createDefaultFeeConfiguration(_platformTreasury);

//         // Validate configuration
//         FeeLib.validateFeeConfiguration(feeConfig);

//         // Deploy the swap limit hook
//         swapLimitHook = new EarlySwapLimitHook(_poolManager, address(this));
//     }

//     /**
//      * @dev Create an instant party - token and pool created immediately
//      */
//     function createInstantParty(
//         PartyTypes.TokenMetadata calldata metadata
//     ) external payable nonReentrant returns (uint256 partyId) {
//         PartyLib.validatePartyCreation(msg.sender, metadata);

//         partyId = ++partyCounter;

//         // Create party using library
//         PartyTypes.Party memory party = PartyLib.createInstantParty(
//             partyId,
//             msg.sender,
//             metadata,
//             msg.value
//         );

//         // Store party
//         parties[partyId] = party;
//         PartyLib.addPartyToUser(userParties, msg.sender, partyId);

//         // Launch immediately
//         _launchParty(partyId, msg.value);

//         return partyId;
//     }

//     /**
//      * @dev Create a public party - deploys a venue contract
//      */
//     function createPublicParty(
//         PartyTypes.TokenMetadata calldata metadata,
//         uint256 targetLiquidity
//     ) external returns (uint256 partyId) {
//         PartyLib.validatePartyCreation(msg.sender, metadata);

//         partyId = ++partyCounter;

//         // Create party and venue using library
//         (PartyTypes.Party memory party, ) = PartyLib.createPublicParty(
//             partyId,
//             msg.sender,
//             metadata,
//             targetLiquidity
//         );

//         // Store party
//         parties[partyId] = party;
//         PartyLib.addPartyToUser(userParties, msg.sender, partyId);

//         return partyId;
//     }

//     /**
//      * @dev Create a private party - deploys a venue contract with signature-based authorization
//      */
//     function createPrivateParty(
//         PartyTypes.TokenMetadata calldata metadata,
//         uint256 targetLiquidity,
//         address signerAddress
//     ) external returns (uint256 partyId) {
//         PartyLib.validatePartyCreation(msg.sender, metadata);

//         partyId = ++partyCounter;

//         // Create party and venue using library
//         (PartyTypes.Party memory party, ) = PartyLib.createPrivateParty(
//             partyId,
//             msg.sender,
//             metadata,
//             targetLiquidity,
//             signerAddress
//         );

//         // Store party
//         parties[partyId] = party;
//         PartyLib.addPartyToUser(userParties, msg.sender, partyId);

//         return partyId;
//     }

//     /**
//      * @dev Handle launch from venue contract
//      */
//     function launchFromVenue(uint256 partyId) external payable nonReentrant {
//         PartyTypes.Party storage party = parties[partyId];

//         PartyErrors.requireAuthorized(
//             party.venueAddress == msg.sender,
//             PartyErrors.ErrorCode.ONLY_VENUE_CAN_LAUNCH
//         );
//         PartyErrors.requireValidState(
//             !party.launched,
//             PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
//         );
//         PartyErrors.requireNonZero(
//             msg.value,
//             PartyErrors.ErrorCode.NO_FUNDS_RECEIVED
//         );

//         party.totalLiquidity = msg.value;
//         _launchParty(partyId, msg.value);
//     }

//     /**
//      * @dev Internal function to launch a party
//      */
//     function _launchParty(uint256 partyId, uint256 ethAmount) internal {
//         PartyTypes.Party storage party = parties[partyId];

//         // Execute launch using external library
//         PartyTypes.LPPosition memory lpPosition = LaunchLib.executePartyLaunch(
//             partyId,
//             ethAmount,
//             party,
//             feeConfig,
//             partyVault,
//             poolManager,
//             weth,
//             swapLimitHook,
//             defaultMaxSwapCount,
//             defaultMaxSwapPercentBPS
//         );

//         // Store LP position and mark fees as claimable
//         lpPositions[partyId] = lpPosition;
//         canClaimFees[party.tokenAddress] = true;
//     }

//     /**
//      * @dev Claim fees from LP position (only token creator)
//      */
//     function claimFees(uint256 partyId) external nonReentrant {
//         PartyTypes.Party storage party = parties[partyId];
//         PartyTypes.LPPosition storage position = lpPositions[partyId];

//         // Cache frequently accessed values to avoid multiple storage reads
//         address creator = party.creator;
//         address tokenAddress = party.tokenAddress;
//         bool launched = party.launched;
//         bool feesClaimable = position.feesClaimable;

//         PartyErrors.requireAuthorized(
//             creator == msg.sender,
//             PartyErrors.ErrorCode.ONLY_CREATOR_CAN_CLAIM
//         );
//         PartyErrors.requireValidState(
//             launched,
//             PartyErrors.ErrorCode.PARTY_NOT_LAUNCHED
//         );
//         PartyErrors.requireValidState(
//             canClaimFees[tokenAddress],
//             PartyErrors.ErrorCode.FEES_NOT_CLAIMABLE
//         );
//         PartyErrors.requireValidState(
//             feesClaimable,
//             PartyErrors.ErrorCode.FEES_ALREADY_CLAIMED
//         );

//         // Get available fees (simplified approach)
//         uint256 totalFees = address(this).balance;

//         // Process fee claim
//         (uint256 devAmount, uint256 platformAmount) = FeeLib.processFeesClaim(
//             totalFees,
//             feeConfig.devFeeShare
//         );

//         // Burn remaining tokens
//         UniswapV4ERC20 token = UniswapV4ERC20(tokenAddress);
//         uint256 tokenBalance = TokenLib.getTokenBalance(token, address(this));
//         TokenLib.burnTokens(token, tokenBalance);

//         // Transfer dev fees
//         FeeLib.transferDevFees(creator, devAmount);

//         // Mark fees as claimed (batch storage writes)
//         position.feesClaimable = false;
//         canClaimFees[tokenAddress] = false;

//         emit FeesClaimedByDev(partyId, creator, devAmount, platformAmount);
//     }

//     // View functions
//     function getParty(
//         uint256 partyId
//     ) external view returns (PartyTypes.Party memory) {
//         return parties[partyId];
//     }

//     function getUserParties(
//         address user
//     ) external view returns (uint256[] memory) {
//         return userParties[user];
//     }

//     function getLPPosition(
//         uint256 partyId
//     ) external view returns (PartyTypes.LPPosition memory) {
//         return lpPositions[partyId];
//     }

//     // Admin functions
//     function updateFeeConfiguration(
//         PartyTypes.FeeConfiguration calldata newConfig
//     ) external onlyOwner {
//         FeeLib.validateFeeConfiguration(newConfig);
//         feeConfig = newConfig;
//     }

//     function updateSwapLimitDefaults(
//         uint256 maxSwapCount,
//         uint256 maxSwapPercentBPS
//     ) external onlyOwner {
//         ConfigLib.validateSwapLimitConfig(maxSwapCount, maxSwapPercentBPS);

//         defaultMaxSwapCount = maxSwapCount;
//         defaultMaxSwapPercentBPS = maxSwapPercentBPS;
//     }

//     /**
//      * @dev Withdraw accumulated platform fees (only owner)
//      */
//     function withdrawPlatformFees() external onlyOwner {
//         uint256 balance = address(this).balance;
//         PartyErrors.requireNonZero(
//             balance,
//             PartyErrors.ErrorCode.NO_FEES_TO_WITHDRAW
//         );

//         FeeLib.transferPlatformFees(feeConfig.platformTreasury, balance);
//     }

//     /**
//      * @dev Update platform treasury address (only owner)
//      */
//     function updatePlatformTreasury(address newTreasury) external onlyOwner {
//         PartyErrors.requireNonZeroAddress(
//             newTreasury,
//             PartyErrors.ErrorCode.ZERO_ADDRESS
//         );
//         feeConfig.platformTreasury = newTreasury;
//     }

//     /**
//      * @dev Get current platform treasury address
//      */
//     function platformTreasury() external view returns (address) {
//         return feeConfig.platformTreasury;
//     }

//     /**
//      * @dev Allow contract to receive ETH
//      */
//     receive() external payable {}
// }
