// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PartyTypes
 * @dev Centralized definitions for all party-related types and structures
 * Updated for Uniswap V3 integration
 */
library PartyTypes {
    enum PartyType {
        INSTANT,
        PUBLIC,
        PRIVATE
    }

    struct TokenMetadata {
        string name;
        string symbol;
        string description;
        string image;
        string website;
        string twitter;
        string telegram;
    }

    struct Party {
        uint256 id;
        PartyType partyType;
        address creator;
        TokenMetadata metadata;
        address tokenAddress;
        address venueAddress; // Only for public/private parties
        address poolAddress; // V3 pool address
        uint256 totalLiquidity;
        uint256 targetSupply; // Target tokens for presale (only for public/private parties)
        bool launched;
        uint256 createdAt;
        uint256 timeoutDeadline; // Timestamp when anyone can launch
        bool timeoutLaunched; // Whether the party was launched via timeout
    }

    struct LPPosition {
        address poolAddress; // V3 pool address
        address tokenAddress;
        uint256 tokenId; // NFT token ID for the LP position from NonfungiblePositionManager
        uint24 fee; // V3 fee tier
        int24 tickLower; // Lower tick of the position
        int24 tickUpper; // Upper tick of the position
        uint128 liquidity; // Amount of liquidity in the position
        bool feesClaimable;
    }

    struct TokenDistribution {
        uint256 totalSupply; // Always FIXED_TOTAL_SUPPLY (1B)
        uint256 presaleTokens; // Tokens allocated to presale
        uint256 liquidityTokens; // Tokens for DEX liquidity
        uint256 creatorTokens; // Tokens for creator
        uint256 vaultTokens; // Tokens for vault
    }

    struct FeeConfiguration {
        uint256 platformFeeBPS;
        uint256 vaultFeeBPS;
        uint256 devFeeShare;
        address platformTreasury;
    }

    struct SwapLimitConfig {
        uint256 maxSwapCount;
        uint256 maxSwapPercentBPS;
        address tokenAddress;
        uint256 tokenSupply;
        uint256 currentSwapCount;
        bool isActive;
    }

    // Constants
    uint256 constant FIXED_TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18; // 1B tokens (fixed)
    uint256 constant MIN_PRESALE_SUPPLY = 100_000_000 * 10 ** 18; // 100M tokens minimum for presale
    uint256 constant MAX_PRESALE_SUPPLY = 900_000_000 * 10 ** 18; // 900M tokens maximum for presale
    uint256 constant DEFAULT_CREATOR_PERCENTAGE = 0; // 0% for creator
    uint256 constant DEFAULT_VAULT_PERCENTAGE = 1; // 1% for vault

    uint256 constant PLATFORM_FEE_BPS = 100; // 1%
    uint256 constant VAULT_FEE_BPS = 100; // 1% of token supply
    uint256 constant DEV_FEE_SHARE = 50; // 50% of fees to dev

    // V3 specific constants
    uint24 constant DEFAULT_FEE = 10000; // 1% fee tier
    int24 constant DEFAULT_TICK_SPACING = 200; // Tick spacing for 1%

    // V3 tick range for full range liquidity
    int24 constant MIN_TICK = -887272;
    int24 constant MAX_TICK = 887272;

    // Metadata immutability tracking
    struct MetadataFieldStatus {
        bool nameSet;
        bool symbolSet;
        bool descriptionSet;
        bool imageSet;
        bool websiteSet;
        bool twitterSet;
        bool telegramSet;
    }

    // Events for metadata updates
    event MetadataUpdated(
        uint256 indexed partyId,
        string fieldName,
        string fieldValue,
        address indexed updatedBy,
        uint256 timestamp
    );

    event MetadataBatchUpdated(
        uint256 indexed partyId,
        string[] fieldNames,
        string[] fieldValues,
        address indexed updatedBy,
        uint256 timestamp
    );
}
