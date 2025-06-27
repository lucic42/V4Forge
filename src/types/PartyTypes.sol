// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";

/**
 * @title PartyTypes
 * @dev Centralized definitions for all party-related types and structures
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
        PoolId poolId;
        uint256 totalLiquidity;
        bool launched;
        uint256 createdAt;
    }

    struct LPPosition {
        PoolKey poolKey;
        PoolId poolId;
        address tokenAddress;
        uint256 tokenId; // NFT token ID for the LP position
        bool feesClaimable;
    }

    struct TokenDistribution {
        uint256 totalSupply;
        uint256 liquidityTokens;
        uint256 creatorTokens;
        uint256 vaultTokens;
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
    uint256 constant DEFAULT_TOTAL_SUPPLY = 1_000_000 * 10 ** 18; // 1M tokens
    uint256 constant DEFAULT_LIQUIDITY_TOKENS = 800_000 * 10 ** 18; // 800K for liquidity
    uint256 constant DEFAULT_CREATOR_TOKENS = 190_000 * 10 ** 18; // 190K for creator
    uint256 constant DEFAULT_VAULT_TOKENS = 10_000 * 10 ** 18; // 10K for vault (1%)

    uint256 constant PLATFORM_FEE_BPS = 100; // 1%
    uint256 constant VAULT_FEE_BPS = 100; // 1% of token supply
    uint256 constant DEV_FEE_SHARE = 50; // 50% of fees to dev

    uint24 constant DEFAULT_FEE = 3000; // 0.3%
    int24 constant DEFAULT_TICK_SPACING = 60;
}
