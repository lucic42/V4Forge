// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {PartyTypes} from "../../src/types/PartyTypes.sol";
import {PartyErrors} from "../../src/types/PartyErrors.sol";
import {PartyVault} from "../../src/vault/PartyVault.sol";
import {PartyVenue} from "../../src/venue/PartyVenue.sol";
import {UniswapV4ERC20} from "../../src/tokens/UniswapV4ERC20.sol";
import {IPartyStarter} from "../../src/interfaces/IPartyStarter.sol";
import {EarlySwapLimitHook} from "../../src/hooks/EarlySwapLimitHook.sol";

// Libraries
import {PartyLib} from "../../src/libraries/PartyLib.sol";
import {LaunchLib} from "../../src/libraries/LaunchLib.sol";
import {FeeLib} from "../../src/libraries/FeeLib.sol";
import {TokenLib} from "../../src/libraries/TokenLib.sol";
import {PoolLib} from "../../src/libraries/PoolLib.sol";
import {ConfigLib} from "../../src/libraries/ConfigLib.sol";

/**
 * @title PartyStarterWithHook
 * @dev Test version of PartyStarter with a working hook for testing
 * This contract includes the same functionality as PartyStarter but with enhanced testing capabilities
 */
contract PartyStarterWithHook is Owned, ReentrancyGuard, IPartyStarter {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using PartyErrors for *;

    // Immutable dependencies
    IPoolManager public immutable poolManager;
    PartyVault public immutable partyVault;
    EarlySwapLimitHook public immutable swapLimitHook;
    address public immutable weth;

    // Configuration
    PartyTypes.FeeConfiguration public feeConfig;
    uint256 public defaultMaxSwapCount = 50;
    uint256 public defaultMaxSwapPercentBPS = 200; // 2%

    // State
    uint256 public partyCounter;
    mapping(uint256 => PartyTypes.Party) public parties;
    mapping(address => uint256[]) public userParties;
    mapping(uint256 => PartyTypes.LPPosition) public lpPositions;
    mapping(address => bool) public canClaimFees;

    constructor(
        IPoolManager _poolManager,
        PartyVault _partyVault,
        address _weth,
        address _platformTreasury,
        EarlySwapLimitHook _swapLimitHook
    ) Owned(msg.sender) {
        // Validate system addresses
        ConfigLib.validateSystemAddresses(
            address(_poolManager),
            address(_partyVault),
            _weth,
            _platformTreasury
        );

        poolManager = _poolManager;
        partyVault = _partyVault;
        weth = _weth;
        swapLimitHook = _swapLimitHook;

        // Initialize fee configuration using library
        feeConfig = ConfigLib.createDefaultFeeConfiguration(_platformTreasury);

        // Validate configuration
        FeeLib.validateFeeConfiguration(feeConfig);
    }

    /**
     * @dev Create an instant party - token and pool created immediately
     */
    function createInstantParty(
        PartyTypes.TokenMetadata calldata metadata
    ) external payable nonReentrant returns (uint256 partyId) {
        PartyLib.validatePartyCreation(msg.sender, metadata);

        PartyErrors.requireNonZero(
            msg.value,
            PartyErrors.ErrorCode.ZERO_AMOUNT
        );

        partyId = ++partyCounter;

        // Create party using library
        PartyTypes.Party memory party = PartyLib.createInstantParty(
            partyId,
            msg.sender,
            metadata,
            msg.value
        );

        // Store party
        parties[partyId] = party;
        PartyLib.addPartyToUser(userParties, msg.sender, partyId);

        // Launch immediately
        _launchParty(partyId, msg.value);

        return partyId;
    }

    /**
     * @dev Create a public party - requires contributions to reach target
     */
    function createPublicParty(
        PartyTypes.TokenMetadata calldata metadata,
        uint256 targetLiquidity
    ) external returns (uint256 partyId) {
        PartyLib.validatePartyCreation(msg.sender, metadata);

        PartyErrors.requireNonZero(
            targetLiquidity,
            PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
        );

        partyId = ++partyCounter;

        // Create party and venue using library
        (PartyTypes.Party memory party, PartyVenue venue) = PartyLib
            .createPublicParty(partyId, msg.sender, metadata, targetLiquidity);
        address venueAddress = address(venue);

        // Store party
        parties[partyId] = party;
        PartyLib.addPartyToUser(userParties, msg.sender, partyId);

        emit VenueDeployed(partyId, venueAddress);

        return partyId;
    }

    /**
     * @dev Create a private party - requires signature-based authorization
     */
    function createPrivateParty(
        PartyTypes.TokenMetadata calldata metadata,
        uint256 targetLiquidity,
        address signerAddress
    ) external returns (uint256 partyId) {
        PartyLib.validatePartyCreation(msg.sender, metadata);

        PartyErrors.requireNonZero(
            targetLiquidity,
            PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
        );
        PartyErrors.requireNonZeroAddress(
            signerAddress,
            PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS
        );

        partyId = ++partyCounter;

        // Create party and venue using library
        (PartyTypes.Party memory party, PartyVenue venue) = PartyLib
            .createPrivateParty(
                partyId,
                msg.sender,
                metadata,
                targetLiquidity,
                signerAddress
            );
        address venueAddress = address(venue);

        // Store party
        parties[partyId] = party;
        PartyLib.addPartyToUser(userParties, msg.sender, partyId);

        emit VenueDeployed(partyId, venueAddress);

        return partyId;
    }

    /**
     * @dev Handle launch from venue contract
     */
    function launchFromVenue(uint256 partyId) external payable nonReentrant {
        PartyTypes.Party storage party = parties[partyId];

        PartyErrors.requireAuthorized(
            party.venueAddress == msg.sender,
            PartyErrors.ErrorCode.ONLY_VENUE_CAN_LAUNCH
        );
        PartyErrors.requireValidState(
            !party.launched,
            PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
        );
        PartyErrors.requireNonZero(
            msg.value,
            PartyErrors.ErrorCode.ZERO_AMOUNT
        );

        party.totalLiquidity = msg.value;
        _launchParty(partyId, msg.value);
    }

    /**
     * @dev Internal function to launch a party
     */
    function _launchParty(uint256 partyId, uint256 ethAmount) internal {
        PartyTypes.Party storage party = parties[partyId];

        // Validate metadata
        TokenLib.validateTokenMetadata(party.metadata);

        // Create token
        UniswapV4ERC20 token = TokenLib.createToken(partyId, party.metadata);

        // Mint and distribute tokens
        PartyTypes.TokenDistribution memory distribution = TokenLib
            .mintAndDistributeTokens(token, partyId, party.creator, partyVault);

        // Calculate and transfer platform fees
        (uint256 platformFee, uint256 liquidityAmount) = FeeLib
            .calculatePlatformFees(ethAmount, feeConfig);

        FeeLib.transferPlatformFees(feeConfig.platformTreasury, platformFee);

        // Create pool and position
        (PoolId poolId, PoolKey memory poolKey) = PoolLib
            .createPoolAndBurnLiquidity(
                poolManager,
                address(token),
                weth,
                address(swapLimitHook),
                liquidityAmount,
                distribution.liquidityTokens,
                partyId
            );

        // Configure swap limits
        swapLimitHook.configureSwapLimits(
            poolKey,
            address(token),
            defaultMaxSwapCount,
            defaultMaxSwapPercentBPS
        );

        // Update party state
        PartyLib.updatePartyOnLaunch(
            party,
            address(token),
            poolId,
            liquidityAmount
        );

        // Store LP position
        lpPositions[partyId] = PoolLib.createLPPosition(
            poolKey,
            poolId,
            address(token)
        );
        canClaimFees[address(token)] = true;

        // Emit events
        emit PartySystemTokenLaunched(
            partyId,
            address(token),
            party.creator,
            party.metadata.name,
            party.metadata.symbol,
            poolId,
            liquidityAmount,
            block.timestamp
        );

        emit PartyLaunched(partyId, address(token), poolId, liquidityAmount);
    }

    /**
     * @dev Claim fees from LP position (only token creator)
     */
    function claimFees(uint256 partyId) external {
        PartyTypes.Party storage party = parties[partyId];
        PartyTypes.LPPosition storage position = lpPositions[partyId];

        // Cache frequently accessed values to avoid multiple storage reads
        address creator = party.creator;
        address tokenAddress = party.tokenAddress;
        bool launched = party.launched;
        bool feesClaimable = position.feesClaimable;

        PartyErrors.requireAuthorized(
            creator == msg.sender,
            PartyErrors.ErrorCode.ONLY_CREATOR_CAN_CLAIM
        );
        PartyErrors.requireValidState(
            launched,
            PartyErrors.ErrorCode.PARTY_NOT_LAUNCHED
        );
        PartyErrors.requireValidState(
            canClaimFees[tokenAddress],
            PartyErrors.ErrorCode.FEES_NOT_CLAIMABLE
        );
        PartyErrors.requireValidState(
            feesClaimable,
            PartyErrors.ErrorCode.FEES_NOT_CLAIMABLE
        );

        // Get available fees (simplified approach)
        uint256 totalFees = address(this).balance;

        // Process fee claim
        (uint256 devAmount, uint256 platformAmount) = FeeLib.processFeesClaim(
            totalFees,
            feeConfig.devFeeShare
        );

        // Burn remaining tokens
        UniswapV4ERC20 token = UniswapV4ERC20(tokenAddress);
        uint256 tokenBalance = TokenLib.getTokenBalance(token, address(this));
        TokenLib.burnTokens(token, tokenBalance);

        // Transfer dev fees
        FeeLib.transferDevFees(creator, devAmount);

        // Mark fees as claimed
        position.feesClaimable = false;
        canClaimFees[tokenAddress] = false;

        emit FeesClaimedByDev(partyId, creator, devAmount, platformAmount);
    }

    // View functions
    function getParty(
        uint256 partyId
    ) external view returns (PartyTypes.Party memory) {
        return parties[partyId];
    }

    function getUserParties(
        address user
    ) external view returns (uint256[] memory) {
        return userParties[user];
    }

    function getLPPosition(
        uint256 partyId
    ) external view returns (PartyTypes.LPPosition memory) {
        return lpPositions[partyId];
    }

    // Admin functions
    function updateFeeConfiguration(
        PartyTypes.FeeConfiguration calldata newConfig
    ) external onlyOwner {
        FeeLib.validateFeeConfiguration(newConfig);
        feeConfig = newConfig;
    }

    function updateSwapLimitDefaults(
        uint256 maxSwapCount,
        uint256 maxSwapPercentBPS
    ) external onlyOwner {
        ConfigLib.validateSwapLimitConfig(maxSwapCount, maxSwapPercentBPS);

        defaultMaxSwapCount = maxSwapCount;
        defaultMaxSwapPercentBPS = maxSwapPercentBPS;
    }

    /**
     * @dev Withdraw accumulated platform fees (only owner)
     */
    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        PartyErrors.requireNonZero(
            balance,
            PartyErrors.ErrorCode.NO_FEES_TO_WITHDRAW
        );

        FeeLib.transferPlatformFees(feeConfig.platformTreasury, balance);
    }

    /**
     * @dev Update platform treasury address (only owner)
     */
    function updatePlatformTreasury(address newTreasury) external onlyOwner {
        PartyErrors.requireNonZeroAddress(
            newTreasury,
            PartyErrors.ErrorCode.ZERO_ADDRESS
        );
        feeConfig.platformTreasury = newTreasury;
    }

    /**
     * @dev Get current platform treasury address
     */
    function platformTreasury() external view returns (address) {
        return feeConfig.platformTreasury;
    }

    /**
     * @dev Allow contract to receive ETH
     */
    receive() external payable {}
}
