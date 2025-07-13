// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PartyTypes} from "../types/PartyTypes.sol";

/**
 * @title VenueRewardLib
 * @dev Library for managing venue-based reward calculations and distributions
 * Provides utilities for holding duration tracking and LP fee distribution
 */
library VenueRewardLib {
    // Constants for reward calculations
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MAX_HOLDING_MULTIPLIER = 20000; // 200% max
    uint256 private constant DEFAULT_HOLDING_TIME_FOR_MAX = 30 days;

    // Structs for reward calculations
    struct RewardCalculation {
        uint256 baseReward; // Base reward from contribution percentage
        uint256 holdingBonus; // Bonus from holding duration
        uint256 totalReward; // Combined reward
        uint256 holdingMultiplier; // Multiplier applied (in basis points)
        uint256 effectiveHoldingTime; // Total effective holding time
    }

    struct ContributorRewardData {
        uint256 contributionAmount;
        uint256 contributionPercentage;
        uint256 totalHoldingTime;
        uint256 currentHoldingTime;
        bool isCurrentlyHolding;
        uint256 feesClaimedTotal;
    }

    /**
     * @dev Calculate detailed reward breakdown for a contributor
     * @param contributorData The contributor's data
     * @param totalFeesCollected Total LP fees collected by venue
     * @param totalContributions Total contributions made to the presale
     * @param maxHoldingReward Maximum holding reward multiplier (basis points)
     * @param holdingTimeRequired Time required to reach max reward
     * @return calculation Detailed reward calculation breakdown
     */
    function calculateDetailedRewards(
        ContributorRewardData memory contributorData,
        uint256 totalFeesCollected,
        uint256 totalContributions,
        uint256 maxHoldingReward,
        uint256 holdingTimeRequired
    ) external view returns (RewardCalculation memory calculation) {
        // Calculate base reward from contribution percentage
        if (totalContributions > 0 && contributorData.contributionAmount > 0) {
            uint256 contributionShare = (contributorData.contributionAmount *
                PRECISION) / totalContributions;
            calculation.baseReward =
                (totalFeesCollected * contributionShare) /
                PRECISION;
        }

        // Calculate effective holding time
        calculation.effectiveHoldingTime = contributorData.totalHoldingTime;
        if (contributorData.isCurrentlyHolding) {
            calculation.effectiveHoldingTime += contributorData
                .currentHoldingTime;
        }

        // Calculate holding multiplier
        if (calculation.effectiveHoldingTime > 0 && holdingTimeRequired > 0) {
            calculation.holdingMultiplier =
                (calculation.effectiveHoldingTime * BASIS_POINTS) /
                holdingTimeRequired;

            // Cap the multiplier
            uint256 maxMultiplier = maxHoldingReward - BASIS_POINTS; // Subtract base 100%
            if (calculation.holdingMultiplier > maxMultiplier) {
                calculation.holdingMultiplier = maxMultiplier;
            }
        }

        // Calculate holding bonus
        calculation.holdingBonus =
            (calculation.baseReward * calculation.holdingMultiplier) /
            BASIS_POINTS;

        // Calculate total reward
        calculation.totalReward =
            calculation.baseReward +
            calculation.holdingBonus;

        // Subtract already claimed fees
        if (calculation.totalReward > contributorData.feesClaimedTotal) {
            calculation.totalReward -= contributorData.feesClaimedTotal;
        } else {
            calculation.totalReward = 0;
        }

        return calculation;
    }

    /**
     * @dev Calculate simple claimable amount (for gas-optimized calls)
     * @param contributionAmount How much ETH the contributor provided
     * @param totalContributions Total ETH contributed to presale
     * @param totalFeesCollected Total LP fees collected
     * @param holdingTime Total time holding tokens (seconds)
     * @param holdingTimeForMax Time required for maximum bonus
     * @param maxBonusBPS Maximum bonus in basis points (e.g., 10000 = 100% bonus)
     * @param alreadyClaimed Amount already claimed by this contributor
     * @return claimableAmount The amount the contributor can claim
     */
    function calculateClaimableAmount(
        uint256 contributionAmount,
        uint256 totalContributions,
        uint256 totalFeesCollected,
        uint256 holdingTime,
        uint256 holdingTimeForMax,
        uint256 maxBonusBPS,
        uint256 alreadyClaimed
    ) external pure returns (uint256 claimableAmount) {
        if (contributionAmount == 0 || totalContributions == 0) {
            return 0;
        }

        // Calculate base reward
        uint256 baseReward = (totalFeesCollected * contributionAmount) /
            totalContributions;

        // Calculate holding bonus
        uint256 holdingBonus = 0;
        if (holdingTime > 0 && holdingTimeForMax > 0) {
            uint256 holdingMultiplier = (holdingTime * maxBonusBPS) /
                holdingTimeForMax;
            if (holdingMultiplier > maxBonusBPS) {
                holdingMultiplier = maxBonusBPS;
            }
            holdingBonus = (baseReward * holdingMultiplier) / BASIS_POINTS;
        }

        uint256 totalEarned = baseReward + holdingBonus;

        // Subtract already claimed
        if (totalEarned > alreadyClaimed) {
            claimableAmount = totalEarned - alreadyClaimed;
        } else {
            claimableAmount = 0;
        }

        return claimableAmount;
    }

    /**
     * @dev Calculate holding time bonus percentage
     * @param holdingTime Time held in seconds
     * @param timeForMaxBonus Time required for maximum bonus
     * @return bonusPercentage Bonus percentage (0-10000 basis points)
     */
    function calculateHoldingBonus(
        uint256 holdingTime,
        uint256 timeForMaxBonus
    ) internal pure returns (uint256 bonusPercentage) {
        if (holdingTime == 0 || timeForMaxBonus == 0) {
            return 0;
        }

        bonusPercentage = (holdingTime * BASIS_POINTS) / timeForMaxBonus;

        // Cap at 100% bonus
        if (bonusPercentage > BASIS_POINTS) {
            bonusPercentage = BASIS_POINTS;
        }

        return bonusPercentage;
    }

    /**
     * @dev Validate reward configuration parameters
     * @param maxHoldingReward Maximum holding reward (basis points)
     * @param holdingTimeRequired Time required for max reward
     */
    function validateRewardConfig(
        uint256 maxHoldingReward,
        uint256 holdingTimeRequired
    ) external pure {
        require(maxHoldingReward >= BASIS_POINTS, "Max reward too low");
        require(
            maxHoldingReward <= MAX_HOLDING_MULTIPLIER,
            "Max reward too high"
        );
        require(holdingTimeRequired > 0, "Holding time cannot be zero");
        require(holdingTimeRequired <= 365 days, "Holding time too long");
    }

    /**
     * @dev Calculate contribution percentage with precision
     * @param contribution Individual contribution amount
     * @param totalContributions Total contributions
     * @return percentage Percentage in basis points (0-10000)
     */
    function calculateContributionPercentage(
        uint256 contribution,
        uint256 totalContributions
    ) external pure returns (uint256 percentage) {
        if (totalContributions == 0) {
            return 0;
        }

        percentage = (contribution * BASIS_POINTS) / totalContributions;

        // Ensure we don't exceed 100%
        if (percentage > BASIS_POINTS) {
            percentage = BASIS_POINTS;
        }

        return percentage;
    }

    /**
     * @dev Calculate token distribution amounts for presale contributors
     * @param contributions Array of contribution amounts
     * @param totalTokens Total tokens to distribute
     * @return tokenAmounts Array of token amounts for each contributor
     */
    function calculateTokenDistribution(
        uint256[] memory contributions,
        uint256 totalTokens
    ) external pure returns (uint256[] memory tokenAmounts) {
        require(contributions.length > 0, "No contributions");
        require(totalTokens > 0, "No tokens to distribute");

        tokenAmounts = new uint256[](contributions.length);

        // Calculate total contributions
        uint256 totalContributions = 0;
        for (uint256 i = 0; i < contributions.length; i++) {
            totalContributions += contributions[i];
        }

        require(totalContributions > 0, "No total contributions");

        // Calculate proportional token amounts
        for (uint256 i = 0; i < contributions.length; i++) {
            if (contributions[i] > 0) {
                tokenAmounts[i] =
                    (totalTokens * contributions[i]) /
                    totalContributions;
            }
        }

        return tokenAmounts;
    }

    /**
     * @dev Check if enough time has passed for claiming rewards
     * @param lastClaimTime Last time rewards were claimed
     * @param minimumClaimInterval Minimum time between claims
     * @return canClaim Whether enough time has passed
     */
    function canClaimRewards(
        uint256 lastClaimTime,
        uint256 minimumClaimInterval
    ) external view returns (bool canClaim) {
        if (lastClaimTime == 0) {
            return true; // First claim
        }

        return (block.timestamp >= lastClaimTime + minimumClaimInterval);
    }

    /**
     * @dev Estimate future rewards based on current holding time
     * @param currentRewards Current claimable rewards
     * @param currentHoldingTime Current holding duration
     * @param projectedHoldingTime Future holding duration to project to
     * @param timeForMaxBonus Time required for maximum bonus
     * @param maxBonusBPS Maximum bonus in basis points
     * @return projectedRewards Estimated future rewards
     */
    function projectFutureRewards(
        uint256 currentRewards,
        uint256 currentHoldingTime,
        uint256 projectedHoldingTime,
        uint256 timeForMaxBonus,
        uint256 maxBonusBPS
    ) external pure returns (uint256 projectedRewards) {
        if (projectedHoldingTime <= currentHoldingTime) {
            return currentRewards;
        }

        // Calculate current bonus percentage
        uint256 currentBonus = calculateHoldingBonus(
            currentHoldingTime,
            timeForMaxBonus
        );

        // Calculate projected bonus percentage
        uint256 projectedBonus = calculateHoldingBonus(
            projectedHoldingTime,
            timeForMaxBonus
        );

        // If no current bonus, can't project accurately
        if (currentBonus == 0) {
            return currentRewards;
        }

        // Project based on bonus improvement
        uint256 bonusImprovement = projectedBonus - currentBonus;
        uint256 baseReward = (currentRewards * BASIS_POINTS) /
            (BASIS_POINTS + currentBonus);
        uint256 additionalBonus = (baseReward * bonusImprovement) /
            BASIS_POINTS;

        projectedRewards = currentRewards + additionalBonus;

        return projectedRewards;
    }
}
