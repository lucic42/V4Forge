// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
// import {INonfungiblePositionManager} from "v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
// import {Owned} from "solmate/auth/Owned.sol";
// import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

// // Import our types and interfaces
// import {PartyTypes} from "./types/PartyTypes.sol";
// import {PartyErrors} from "./types/PartyErrors.sol";
// import {IPartyStarterV2} from "./interfaces/IPartyStarterV2.sol";
// import {ISwapRouter02} from "./interfaces/ISwapRouter02.sol";
// import {IWETH} from "./interfaces/IWETH.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// // Import our libraries
// import {PartyLib} from "./libraries/PartyLib.sol";
// import {LaunchV3Lib} from "./libraries/LaunchV3Lib.sol";
// import {TokenLib} from "./libraries/TokenLib.sol";
// import {PoolV3Lib} from "./libraries/PoolV3Lib.sol";
// import {FeeLib} from "./libraries/FeeLib.sol";
// import {ConfigLib} from "./libraries/ConfigLib.sol";

// // Import contracts
// import {UniswapV3ERC20} from "./tokens/UniswapV3ERC20.sol";
// import {PartyVault} from "./vault/PartyVault.sol";
// import {PartyVenue} from "./venue/PartyVenue.sol";

// /**
//  * @title PartyStarter
//  * @dev Main contract for launching tokens with different party types
//  * Migrated to use Uniswap V3 instead of V4
//  */
// contract PartyStarterV2 is Owned, ReentrancyGuard, IPartyStarterV2 {
//     using PartyErrors for *;

//     // Immutable dependencies (V3)
//     IUniswapV3Factory public immutable uniswapFactory;
//     INonfungiblePositionManager public immutable positionManager;
//     ISwapRouter02 public immutable swapRouter;
//     PartyVault public immutable partyVault;
//     address public immutable weth;

//     // Configuration
//     PartyTypes.FeeConfiguration public feeConfig;

//     // State
//     uint256 public partyCounter;
//     mapping(uint256 => PartyTypes.Party) public parties;
//     mapping(address => uint256[]) public userParties;
//     mapping(uint256 => PartyTypes.LPPosition) public lpPositions;
//     mapping(address => bool) public canClaimFees;
//     mapping(uint256 => PartyTypes.MetadataFieldStatus) public metadataStatus;

//     constructor(
//         IUniswapV3Factory _uniswapFactory,
//         INonfungiblePositionManager _positionManager,
//         ISwapRouter02 _swapRouter,
//         PartyVault _partyVault,
//         address _weth,
//         address _platformTreasury
//     ) Owned(msg.sender) {
//         // Validate system addresses
//         ConfigLib.validateSystemAddresses(
//             address(_uniswapFactory),
//             address(_partyVault),
//             _weth,
//             _platformTreasury
//         );

//         uniswapFactory = _uniswapFactory;
//         positionManager = _positionManager;
//         swapRouter = _swapRouter;
//         partyVault = _partyVault;
//         weth = _weth;

//         // Initialize fee configuration using library
//         feeConfig = ConfigLib.createDefaultFeeConfiguration(_platformTreasury);

//         // Validate configuration
//         FeeLib.validateFeeConfiguration(feeConfig);
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

//     function createKlikStyleParty(
//         PartyTypes.TokenMetadata calldata metadata
//     ) external payable nonReentrant returns (uint256 partyId) {
//         PartyLib.validatePartyCreation(msg.sender, metadata);

//         partyId = ++partyCounter;

//         PartyTypes.Party memory party = PartyLib.createInstantParty(
//             partyId,
//             msg.sender,
//             metadata,
//             0 // No initial ETH liquidity
//         );

//         parties[partyId] = party;
//         PartyLib.addPartyToUser(userParties, msg.sender, partyId);

//         _launchOneSidedParty(partyId);

//         if (msg.value > 0) {
//             IWETH(weth).deposit{value: msg.value}();
//             IERC20(weth).approve(address(swapRouter), msg.value);

//             ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
//                 .ExactInputSingleParams({
//                     tokenIn: weth,
//                     tokenOut: parties[partyId].tokenAddress,
//                     fee: PartyTypes.DEFAULT_FEE,
//                     recipient: msg.sender,
//                     amountIn: msg.value,
//                     amountOutMinimum: 0,
//                     sqrtPriceLimitX96: 0
//                 });

//             swapRouter.exactInputSingle(params);
//         }

//         return partyId;
//     }

//     /**
//      * @dev Create a public party - deploys a venue contract (metadata set separately)
//      */
//     function createPublicParty(
//         uint256 targetLiquidity,
//         uint256 targetSupply,
//         uint256 launchTime
//     ) external returns (uint256 partyId) {
//         // Validate target supply
//         PartyErrors.requireValidState(
//             targetSupply >= PartyTypes.MIN_PRESALE_SUPPLY &&
//                 targetSupply <= PartyTypes.MAX_PRESALE_SUPPLY,
//             PartyErrors.ErrorCode.SUPPLY_OUT_OF_RANGE
//         );

//         // Validate launch time (must be in the future)
//         PartyErrors.requireValidState(
//             launchTime > block.timestamp,
//             PartyErrors.ErrorCode.INVALID_LAUNCH_TIME
//         );

//         partyId = ++partyCounter;

//         // Create party and venue using library (no metadata initially)
//         (PartyTypes.Party memory party, ) = PartyLib
//             .createPublicPartyWithoutMetadata(
//                 partyId,
//                 msg.sender,
//                 targetLiquidity,
//                 targetSupply,
//                 launchTime
//             );

//         // Store party
//         parties[partyId] = party;
//         PartyLib.addPartyToUser(userParties, msg.sender, partyId);

//         return partyId;
//     }

//     /**
//      * @dev Create a private party - deploys a venue contract with signature-based authorization (metadata set separately)
//      */
//     function createPrivateParty(
//         uint256 targetLiquidity,
//         uint256 targetSupply,
//         uint256 launchTime,
//         address signerAddress
//     ) external returns (uint256 partyId) {
//         // Validate target supply
//         PartyErrors.requireValidState(
//             targetSupply >= PartyTypes.MIN_PRESALE_SUPPLY &&
//                 targetSupply <= PartyTypes.MAX_PRESALE_SUPPLY,
//             PartyErrors.ErrorCode.SUPPLY_OUT_OF_RANGE
//         );

//         // Validate launch time (must be in the future)
//         PartyErrors.requireValidState(
//             launchTime > block.timestamp,
//             PartyErrors.ErrorCode.INVALID_LAUNCH_TIME
//         );

//         partyId = ++partyCounter;

//         // Create party and venue using library (no metadata initially)
//         (PartyTypes.Party memory party, ) = PartyLib
//             .createPrivatePartyWithoutMetadata(
//                 partyId,
//                 msg.sender,
//                 targetLiquidity,
//                 targetSupply,
//                 launchTime,
//                 signerAddress
//             );

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

//         // Validate that required metadata is set for public/private parties
//         if (party.partyType != PartyTypes.PartyType.INSTANT) {
//             PartyErrors.requireValidState(
//                 bytes(party.metadata.name).length > 0 &&
//                     bytes(party.metadata.symbol).length > 0,
//                 PartyErrors.ErrorCode.METADATA_ALREADY_SET
//             );
//         }

//         party.totalLiquidity = msg.value;

//         // Emit final progress update before launch
//         emit PartyProgressUpdate(
//             partyId,
//             msg.value, // current amount (final)
//             msg.value, // target amount (reached)
//             0, // contributorCount (will be updated by venue events)
//             100, // 100% progress
//             block.timestamp
//         );

//         _launchParty(partyId, msg.value);
//     }

//     /**
//      * @dev Internal function to launch a party
//      */
//     function _launchParty(uint256 partyId, uint256 ethAmount) internal {
//         PartyTypes.Party storage party = parties[partyId];

//         // Execute launch using V3 library
//         PartyTypes.LPPosition memory lpPosition = LaunchV3Lib
//             .executePartyLaunch(
//                 partyId,
//                 ethAmount,
//                 party,
//                 feeConfig,
//                 partyVault,
//                 uniswapFactory,
//                 positionManager,
//                 weth
//             );

//         // Store LP position and mark fees as claimable
//         lpPositions[partyId] = lpPosition;
//         canClaimFees[party.tokenAddress] = true;
//     }

//     function _launchOneSidedParty(uint256 partyId) internal {
//         PartyTypes.Party storage party = parties[partyId];

//         PartyTypes.LPPosition memory lpPosition = LaunchV3Lib
//             .executeOneSidedPartyLaunch(
//                 partyId,
//                 party,
//                 partyVault,
//                 uniswapFactory,
//                 positionManager,
//                 weth
//             );

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

//         // Collect fees from V3 position
//         (uint256 amount0, uint256 amount1) = PoolV3Lib.collectFees(
//             positionManager,
//             position.tokenId,
//             address(this)
//         );

//         // Calculate fee distribution
//         uint256 totalFees = amount0 + amount1; // Simplified - might need conversion logic
//         (uint256 devAmount, uint256 platformAmount) = FeeLib.processFeesClaim(
//             totalFees,
//             feeConfig.devFeeShare
//         );

//         // Burn remaining tokens
//         UniswapV3ERC20 token = UniswapV3ERC20(tokenAddress);
//         uint256 tokenBalance = TokenLib.getTokenBalance(token, address(this));
//         TokenLib.burnTokens(token, tokenBalance);

//         // Transfer dev fees
//         FeeLib.transferDevFees(creator, devAmount);

//         // Mark fees as claimed
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

//     /**
//      * @dev Set metadata for a party in batch (only party creator or owner)
//      */
//     function setPartyMetadata(
//         uint256 partyId,
//         string[] calldata fieldNames,
//         string[] calldata fieldValues
//     ) external {
//         PartyTypes.Party storage party = parties[partyId];

//         PartyErrors.requireAuthorized(
//             party.creator == msg.sender || owner == msg.sender,
//             PartyErrors.ErrorCode.ONLY_CREATOR_CAN_CLAIM
//         );
//         PartyErrors.requireValidState(
//             !party.launched,
//             PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
//         );
//         PartyErrors.requireValidState(
//             fieldNames.length == fieldValues.length && fieldNames.length > 0,
//             PartyErrors.ErrorCode.INVALID_ARRAY_LENGTH
//         );

//         PartyTypes.MetadataFieldStatus storage status = metadataStatus[partyId];

//         for (uint256 i = 0; i < fieldNames.length; i++) {
//             string memory fieldName = fieldNames[i];
//             string memory fieldValue = fieldValues[i];

//             if (keccak256(bytes(fieldName)) == keccak256(bytes("name"))) {
//                 PartyErrors.requireValidState(
//                     !status.nameSet,
//                     PartyErrors.ErrorCode.METADATA_ALREADY_SET
//                 );
//                 party.metadata.name = fieldValue;
//                 status.nameSet = true;
//             } else if (
//                 keccak256(bytes(fieldName)) == keccak256(bytes("symbol"))
//             ) {
//                 PartyErrors.requireValidState(
//                     !status.symbolSet,
//                     PartyErrors.ErrorCode.METADATA_ALREADY_SET
//                 );
//                 party.metadata.symbol = fieldValue;
//                 status.symbolSet = true;
//             } else if (
//                 keccak256(bytes(fieldName)) == keccak256(bytes("description"))
//             ) {
//                 PartyErrors.requireValidState(
//                     !status.descriptionSet,
//                     PartyErrors.ErrorCode.METADATA_ALREADY_SET
//                 );
//                 party.metadata.description = fieldValue;
//                 status.descriptionSet = true;
//             } else if (
//                 keccak256(bytes(fieldName)) == keccak256(bytes("image"))
//             ) {
//                 PartyErrors.requireValidState(
//                     !status.imageSet,
//                     PartyErrors.ErrorCode.METADATA_ALREADY_SET
//                 );
//                 party.metadata.image = fieldValue;
//                 status.imageSet = true;
//             } else if (
//                 keccak256(bytes(fieldName)) == keccak256(bytes("website"))
//             ) {
//                 PartyErrors.requireValidState(
//                     !status.websiteSet,
//                     PartyErrors.ErrorCode.METADATA_ALREADY_SET
//                 );
//                 party.metadata.website = fieldValue;
//                 status.websiteSet = true;
//             } else if (
//                 keccak256(bytes(fieldName)) == keccak256(bytes("twitter"))
//             ) {
//                 PartyErrors.requireValidState(
//                     !status.twitterSet,
//                     PartyErrors.ErrorCode.METADATA_ALREADY_SET
//                 );
//                 party.metadata.twitter = fieldValue;
//                 status.twitterSet = true;
//             } else if (
//                 keccak256(bytes(fieldName)) == keccak256(bytes("telegram"))
//             ) {
//                 PartyErrors.requireValidState(
//                     !status.telegramSet,
//                     PartyErrors.ErrorCode.METADATA_ALREADY_SET
//                 );
//                 party.metadata.telegram = fieldValue;
//                 status.telegramSet = true;
//             } else {
//                 revert("Invalid field name");
//             }

//             emit PartyTypes.MetadataUpdated(
//                 partyId,
//                 fieldName,
//                 fieldValue,
//                 msg.sender,
//                 block.timestamp
//             );
//         }

//         emit PartyTypes.MetadataBatchUpdated(
//             partyId,
//             fieldNames,
//             fieldValues,
//             msg.sender,
//             block.timestamp
//         );
//     }

//     /**
//      * @dev Check if required metadata is set for launching
//      */
//     function isMetadataComplete(uint256 partyId) external view returns (bool) {
//         PartyTypes.MetadataFieldStatus storage status = metadataStatus[partyId];
//         return status.nameSet && status.symbolSet;
//     }

//     // Admin functions
//     function updateFeeConfiguration(
//         PartyTypes.FeeConfiguration calldata newConfig
//     ) external onlyOwner {
//         FeeLib.validateFeeConfiguration(newConfig);
//         feeConfig = newConfig;
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
//      * @dev Emergency function to recover stuck tokens
//      */
//     function emergencyRecoverToken(
//         address tokenAddress,
//         uint256 amount
//     ) external onlyOwner {
//         PartyErrors.requireNonZeroAddress(
//             tokenAddress,
//             PartyErrors.ErrorCode.ZERO_ADDRESS
//         );
//         PartyErrors.requireNonZero(amount, PartyErrors.ErrorCode.ZERO_AMOUNT);

//         UniswapV3ERC20(tokenAddress).transfer(owner, amount);
//     }

//     // Receive function for ETH
//     receive() external payable {
//         // Accept ETH for fee collection
//     }
// }
