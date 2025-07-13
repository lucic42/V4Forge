// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {ERC20} from "solmate/tokens/ERC20.sol";
// import {Owned} from "solmate/auth/Owned.sol";

// /**
//  * @title RewardERC20
//  * @dev ERC20 token with built-in holding rewards that accumulate based on time and balance
//  * Rewards stop accumulating when tokens are transferred or sold
//  */
// contract RewardERC20 is ERC20, Owned {
//     // Reward configuration
//     struct RewardConfig {
//         uint256 rewardRatePerTokenPerSecond; // Rewards earned per token per second (in wei)
//         uint256 rewardPoolTotal; // Total rewards available for distribution
//         uint256 rewardPoolRemaining; // Remaining rewards in the pool
//         bool rewardsActive; // Whether rewards are currently active
//         uint256 rewardStartTime; // When rewards started
//         uint256 rewardEndTime; // When rewards end (0 = no end)
//     }

//     // Individual holder information
//     struct HolderInfo {
//         uint256 lastUpdateTime; // Last time rewards were calculated for this holder
//         uint256 accumulatedRewards; // Total rewards earned but not yet claimed
//         uint256 claimedRewards; // Total rewards already claimed
//         uint256 holdingStartTime; // When this holder first acquired tokens
//         bool hasEverHeld; // Whether this address has ever held tokens
//     }

//     // Events
//     event RewardsConfigured(
//         uint256 rewardRate,
//         uint256 totalPool,
//         uint256 startTime,
//         uint256 endTime
//     );
//     event RewardsClaimed(address indexed holder, uint256 amount);
//     event RewardsUpdated(
//         address indexed holder,
//         uint256 newAccumulated,
//         uint256 forPeriod
//     );
//     event HoldingStatusChanged(
//         address indexed holder,
//         bool isHolding,
//         uint256 timestamp
//     );
//     event RewardsActivated(bool active);

//     // State variables
//     RewardConfig public rewardConfig;
//     mapping(address => HolderInfo) public holderInfo;
//     uint256 public totalRewardsClaimed;
//     uint256 public totalActiveHolders; // Number of holders with non-zero balance

//     // Constants
//     uint256 private constant PRECISION = 1e18;

//     modifier updateRewards(address account) {
//         _updateRewards(account);
//         _;
//     }

//     constructor(
//         string memory name,
//         string memory symbol
//     ) ERC20(name, symbol, 18) Owned(msg.sender) {}

//     /**
//      * @dev Configure the reward system
//      * @param rewardRatePerTokenPerSecond Rate of rewards per token per second
//      * @param totalRewardPool Total amount of rewards available
//      * @param startTime When rewards should start (0 = immediately)
//      * @param endTime When rewards should end (0 = no end)
//      */
//     function configureRewards(
//         uint256 rewardRatePerTokenPerSecond,
//         uint256 totalRewardPool,
//         uint256 startTime,
//         uint256 endTime
//     ) external onlyOwner {
//         require(rewardRatePerTokenPerSecond > 0, "Invalid reward rate");
//         require(totalRewardPool > 0, "Invalid reward pool");
//         require(endTime == 0 || endTime > block.timestamp, "Invalid end time");
//         require(
//             startTime == 0 || startTime <= block.timestamp,
//             "Invalid start time"
//         );

//         rewardConfig = RewardConfig({
//             rewardRatePerTokenPerSecond: rewardRatePerTokenPerSecond,
//             rewardPoolTotal: totalRewardPool,
//             rewardPoolRemaining: totalRewardPool,
//             rewardsActive: true,
//             rewardStartTime: startTime == 0 ? block.timestamp : startTime,
//             rewardEndTime: endTime
//         });

//         emit RewardsConfigured(
//             rewardRatePerTokenPerSecond,
//             totalRewardPool,
//             rewardConfig.rewardStartTime,
//             endTime
//         );
//     }

//     /**
//      * @dev Activate or deactivate rewards
//      */
//     function setRewardsActive(bool active) external onlyOwner {
//         rewardConfig.rewardsActive = active;
//         emit RewardsActivated(active);
//     }

//     /**
//      * @dev Calculate pending rewards for a holder
//      */
//     function getPendingRewards(address holder) public view returns (uint256) {
//         if (!rewardConfig.rewardsActive || balanceOf[holder] == 0) {
//             return holderInfo[holder].accumulatedRewards;
//         }

//         HolderInfo memory info = holderInfo[holder];
//         uint256 currentTime = block.timestamp;

//         // Check if rewards have ended
//         if (
//             rewardConfig.rewardEndTime > 0 &&
//             currentTime > rewardConfig.rewardEndTime
//         ) {
//             currentTime = rewardConfig.rewardEndTime;
//         }

//         // Check if rewards have started
//         if (currentTime < rewardConfig.rewardStartTime) {
//             return info.accumulatedRewards;
//         }

//         uint256 lastUpdate = info.lastUpdateTime;
//         if (lastUpdate < rewardConfig.rewardStartTime) {
//             lastUpdate = rewardConfig.rewardStartTime;
//         }

//         if (currentTime <= lastUpdate) {
//             return info.accumulatedRewards;
//         }

//         uint256 timeHeld = currentTime - lastUpdate;
//         uint256 newRewards = (balanceOf[holder] *
//             rewardConfig.rewardRatePerTokenPerSecond *
//             timeHeld) / PRECISION;

//         // Cap rewards by remaining pool
//         if (newRewards > rewardConfig.rewardPoolRemaining) {
//             newRewards = rewardConfig.rewardPoolRemaining;
//         }

//         return info.accumulatedRewards + newRewards;
//     }

//     /**
//      * @dev Get total rewards claimed by a holder
//      */
//     function getClaimedRewards(address holder) external view returns (uint256) {
//         return holderInfo[holder].claimedRewards;
//     }

//     /**
//      * @dev Get holding duration for a holder (in seconds)
//      */
//     function getHoldingDuration(
//         address holder
//     ) external view returns (uint256) {
//         HolderInfo memory info = holderInfo[holder];
//         if (!info.hasEverHeld || balanceOf[holder] == 0) {
//             return 0;
//         }
//         return block.timestamp - info.holdingStartTime;
//     }

//     /**
//      * @dev Claim accumulated rewards
//      */
//     function claimRewards() external updateRewards(msg.sender) {
//         uint256 rewards = holderInfo[msg.sender].accumulatedRewards;
//         require(rewards > 0, "No rewards to claim");

//         holderInfo[msg.sender].accumulatedRewards = 0;
//         holderInfo[msg.sender].claimedRewards += rewards;
//         totalRewardsClaimed += rewards;
//         rewardConfig.rewardPoolRemaining -= rewards;

//         // Transfer ETH rewards (assumes contract has ETH balance for rewards)
//         (bool success, ) = payable(msg.sender).call{value: rewards}("");
//         require(success, "Reward transfer failed");

//         emit RewardsClaimed(msg.sender, rewards);
//     }

//     /**
//      * @dev Internal function to update rewards for an account
//      */
//     function _updateRewards(address account) internal {
//         if (account == address(0)) return;

//         HolderInfo storage info = holderInfo[account];
//         uint256 pending = getPendingRewards(account);

//         if (pending != info.accumulatedRewards) {
//             uint256 newRewards = pending - info.accumulatedRewards;
//             info.accumulatedRewards = pending;
//             emit RewardsUpdated(account, pending, newRewards);
//         }

//         info.lastUpdateTime = block.timestamp;
//     }

//     /**
//      * @dev Override transfer to update rewards and reset holding periods
//      */
//     function transfer(
//         address to,
//         uint256 amount
//     )
//         public
//         override
//         updateRewards(msg.sender)
//         updateRewards(to)
//         returns (bool)
//     {
//         _handleTransfer(msg.sender, to, amount);
//         return super.transfer(to, amount);
//     }

//     /**
//      * @dev Override transferFrom to update rewards and reset holding periods
//      */
//     function transferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) public override updateRewards(from) updateRewards(to) returns (bool) {
//         _handleTransfer(from, to, amount);
//         return super.transferFrom(from, to, amount);
//     }

//     /**
//      * @dev Handle transfer logic for reward tracking
//      */
//     function _handleTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) internal {
//         // Update holding status for sender
//         if (balanceOf[from] == amount) {
//             // Sender is transferring all tokens - they stop holding
//             emit HoldingStatusChanged(from, false, block.timestamp);
//         }

//         // Update holding status for receiver
//         if (balanceOf[to] == 0 && amount > 0) {
//             // Receiver is getting their first tokens
//             holderInfo[to].holdingStartTime = block.timestamp;
//             holderInfo[to].hasEverHeld = true;
//             totalActiveHolders++;
//             emit HoldingStatusChanged(to, true, block.timestamp);
//         }

//         // Update active holders count for sender
//         if (balanceOf[from] == amount && balanceOf[from] > 0) {
//             totalActiveHolders--;
//         }
//     }

//     /**
//      * @dev Override _mint to handle new holders
//      */
//     function _mint(address to, uint256 amount) internal override {
//         if (balanceOf[to] == 0 && amount > 0) {
//             holderInfo[to].holdingStartTime = block.timestamp;
//             holderInfo[to].lastUpdateTime = block.timestamp;
//             holderInfo[to].hasEverHeld = true;
//             totalActiveHolders++;
//             emit HoldingStatusChanged(to, true, block.timestamp);
//         }
//         super._mint(to, amount);
//     }

//     /**
//      * @dev Override _burn to handle holders losing all tokens
//      */
//     function _burn(address from, uint256 amount) internal override {
//         if (balanceOf[from] == amount && amount > 0) {
//             totalActiveHolders--;
//             emit HoldingStatusChanged(from, false, block.timestamp);
//         }
//         super._burn(from, amount);
//     }

//     /**
//      * @dev Mint tokens (only owner)
//      */
//     function mint(
//         address account,
//         uint256 amount
//     ) external onlyOwner updateRewards(account) {
//         _mint(account, amount);
//     }

//     /**
//      * @dev Burn tokens (only owner)
//      */
//     function burn(
//         address account,
//         uint256 amount
//     ) external onlyOwner updateRewards(account) {
//         _burn(account, amount);
//     }

//     /**
//      * @dev Add ETH to the reward pool
//      */
//     function addRewardPool() external payable onlyOwner {
//         rewardConfig.rewardPoolTotal += msg.value;
//         rewardConfig.rewardPoolRemaining += msg.value;
//     }

//     /**
//      * @dev Emergency withdraw of unused reward pool (only owner)
//      */
//     function withdrawRewardPool(uint256 amount) external onlyOwner {
//         require(
//             amount <= rewardConfig.rewardPoolRemaining,
//             "Insufficient pool balance"
//         );
//         rewardConfig.rewardPoolRemaining -= amount;
//         rewardConfig.rewardPoolTotal -= amount;

//         (bool success, ) = payable(owner).call{value: amount}("");
//         require(success, "Withdrawal failed");
//     }

//     /**
//      * @dev Allow contract to receive ETH for reward pool
//      */
//     receive() external payable {
//         // ETH sent to contract automatically goes to reward pool
//         rewardConfig.rewardPoolTotal += msg.value;
//         rewardConfig.rewardPoolRemaining += msg.value;
//     }

//     /**
//      * @dev Get comprehensive holder information
//      */
//     function getHolderInfo(
//         address holder
//     )
//         external
//         view
//         returns (
//             uint256 balance,
//             uint256 pendingRewards,
//             uint256 claimedRewards,
//             uint256 holdingDuration,
//             bool isCurrentlyHolding
//         )
//     {
//         HolderInfo memory info = holderInfo[holder];
//         return (
//             balanceOf[holder],
//             getPendingRewards(holder),
//             info.claimedRewards,
//             info.hasEverHeld && balanceOf[holder] > 0
//                 ? block.timestamp - info.holdingStartTime
//                 : 0,
//             balanceOf[holder] > 0
//         );
//     }
// }
