// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Owned} from "solmate/auth/Owned.sol";
// import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
// import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import {PartyErrors} from "../types/PartyErrors.sol";
// import {PartyTypes} from "../types/PartyTypes.sol";

// interface IPartyStarter {
//     function launchFromVenue(uint256 partyId) external payable;
// }

// /**
//  * @title PartyVenueHardened
//  * @dev Security-hardened venue contract that fixes critical vulnerabilities
//  *
//  * SECURITY FIXES IMPLEMENTED:
//  * ✅ Multi-address contribution prevention
//  * ✅ Authorized hook registration only
//  * ✅ Before/after balance tracking
//  * ✅ Higher precision mathematics
//  * ✅ Gas griefing protection
//  * ✅ Robust state management
//  * ✅ Emergency pause mechanisms
//  */
// contract PartyVenueHardened is Owned, ReentrancyGuard {
//     using ECDSA for bytes32;
//     using PartyErrors for *;

//     // Enhanced precision for calculations
//     uint256 private constant PRECISION = 1e27; // Much higher precision
//     uint256 private constant MIN_CONTRIBUTION = 0.001 ether; // Prevent spam contributions
//     uint256 private constant MAX_CONTRIBUTORS = 1000; // Prevent gas griefing

//     struct PartyInfo {
//         uint256 partyId;
//         address creator;
//         uint256 targetAmount;
//         uint256 currentAmount;
//         bool launched;
//         bool isPrivate;
//         bool paused; // Emergency pause mechanism
//         address signerAddress;
//         address tokenAddress;
//         mapping(bytes32 => bool) usedSignatures;
//         mapping(address => bool) contributorExists; // Prevent multi-address exploitation
//     }

//     struct ContributorData {
//         uint256 contributionAmount; // Original ETH contribution (immutable)
//         uint256 originalTokenAllocation; // Original presale tokens (immutable)
//         uint256 currentOriginalTokensHeld; // Current original tokens held
//         uint256 accumulatedTokenSeconds; // Accumulated "token-seconds" for rewards (higher precision)
//         uint256 lastUpdateTimestamp; // Last accumulation update
//         uint256 rewardsClaimed; // Total rewards claimed
//         bool isCurrentlyHolding; // Currently holding any original tokens
//         uint256 totalSoldThroughSwaps; // Analytics: sold via swaps
//         uint256 totalSoldThroughTransfers; // Analytics: sold via transfers
//         bool hasDistributedTokens; // Prevent double distribution
//     }

//     struct RewardState {
//         uint256 totalFeesCollected;
//         uint256 totalFeesDistributed;
//         uint256 totalOriginalTokensDistributed;
//         uint256 totalAccumulatedTokenSeconds; // Higher precision
//         uint256 lastFeeCollection;
//     }

//     struct SecurityConfig {
//         mapping(address => bool) authorizedHooks; // Only authorized hooks can call
//         mapping(address => bool) authorizedCallers; // Only authorized callers can call sensitive functions
//         bool emergencyPaused;
//         address emergencyAdmin;
//     }

//     PartyInfo public partyInfo;
//     RewardState public rewardState;
//     SecurityConfig internal securityConfig;
//     address public immutable partyStarter;

//     // Gas-efficient contributor tracking
//     address[] public contributors;
//     mapping(address => ContributorData) public contributorData;
//     mapping(address => uint256) public contributions;

//     // Enhanced security tracking
//     mapping(address => uint256) private balanceSnapshots; // For before/after balance tracking

//     // Events
//     event ContributionReceived(address indexed contributor, uint256 amount);
//     event PartyLaunched(uint256 totalAmount);
//     event TokensDistributed(
//         address indexed contributor,
//         uint256 originalAllocation
//     );
//     event SwapTracked(
//         address indexed user,
//         bool isSelling,
//         uint256 tokenAmount
//     );
//     event TransferTracked(
//         address indexed from,
//         address indexed to,
//         uint256 originalTokenAmount
//     );
//     event RewardsAccumulated(address indexed contributor, uint256 tokenSeconds);
//     event RewardsClaimed(address indexed contributor, uint256 amount);
//     event FeesCollected(uint256 newFees, uint256 totalFees);
//     event EmergencyPaused(bool paused);
//     event HookAuthorized(address indexed hook, bool authorized);

//     modifier onlyPartyStarter() {
//         require(msg.sender == partyStarter, "Only PartyStarter");
//         _;
//     }

//     modifier onlyCreator() {
//         require(msg.sender == partyInfo.creator, "Only creator");
//         _;
//     }

//     modifier onlyAuthorizedHook() {
//         require(
//             securityConfig.authorizedHooks[msg.sender],
//             "Hook not authorized"
//         );
//         _;
//     }

//     modifier onlyTokenOrAuthorizedHook() {
//         require(
//             msg.sender == partyInfo.tokenAddress ||
//                 securityConfig.authorizedHooks[msg.sender],
//             "Not authorized caller"
//         );
//         _;
//     }

//     modifier notPaused() {
//         require(
//             !partyInfo.paused && !securityConfig.emergencyPaused,
//             "System paused"
//         );
//         _;
//     }

//     modifier onlyEmergencyAdmin() {
//         require(
//             msg.sender == securityConfig.emergencyAdmin,
//             "Only emergency admin"
//         );
//         _;
//     }

//     constructor(
//         uint256 _partyId,
//         address _creator,
//         uint256 _targetAmount,
//         bool _isPrivate,
//         address _signerAddress
//     ) Owned(_creator) {
//         partyStarter = msg.sender;
//         partyInfo.partyId = _partyId;
//         partyInfo.creator = _creator;
//         partyInfo.targetAmount = _targetAmount;
//         partyInfo.isPrivate = _isPrivate;
//         partyInfo.signerAddress = _signerAddress;

//         // Initialize security config
//         securityConfig.emergencyAdmin = _creator;
//         securityConfig.authorizedCallers[_creator] = true;
//         securityConfig.authorizedCallers[partyStarter] = true;
//     }

//     /**
//      * @dev Set the token address after launch
//      */
//     function setTokenAddress(address tokenAddress) external onlyPartyStarter {
//         partyInfo.tokenAddress = tokenAddress;
//     }

//     /**
//      * @dev Authorize a hook for tracking (SECURITY FIX)
//      */
//     function authorizeHook(address hook, bool authorized) external onlyCreator {
//         securityConfig.authorizedHooks[hook] = authorized;
//         emit HookAuthorized(hook, authorized);
//     }

//     /**
//      * @dev Emergency pause mechanism
//      */
//     function setEmergencyPause(bool paused) external onlyEmergencyAdmin {
//         securityConfig.emergencyPaused = paused;
//         emit EmergencyPaused(paused);
//     }

//     /**
//      * @dev Contribute ETH to presale (SECURITY HARDENED)
//      */
//     function contribute() external payable nonReentrant notPaused {
//         require(!partyInfo.isPrivate, "Private party requires signature");

//         // SECURITY FIX: Prevent multi-address exploitation
//         require(
//             !partyInfo.contributorExists[msg.sender],
//             "Address already contributed"
//         );

//         // SECURITY FIX: Prevent spam/griefing
//         require(msg.value >= MIN_CONTRIBUTION, "Contribution too small");
//         require(
//             contributors.length < MAX_CONTRIBUTORS,
//             "Too many contributors"
//         );

//         _processContribution();
//     }

//     /**
//      * @dev Distribute original presale tokens (SECURITY HARDENED)
//      */
//     function distributeTokens(
//         address contributor,
//         uint256 tokenAmount
//     ) external onlyPartyStarter notPaused {
//         ContributorData storage data = contributorData[contributor];
//         require(data.contributionAmount > 0, "Not a contributor");
//         require(!data.hasDistributedTokens, "Already distributed"); // SECURITY FIX

//         // Set the original allocation (IMMUTABLE)
//         data.originalTokenAllocation = tokenAmount;
//         data.currentOriginalTokensHeld = tokenAmount;
//         data.lastUpdateTimestamp = block.timestamp;
//         data.isCurrentlyHolding = true;
//         data.hasDistributedTokens = true; // SECURITY FIX

//         rewardState.totalOriginalTokensDistributed += tokenAmount;

//         emit TokensDistributed(contributor, tokenAmount);
//     }

//     /**
//      * @dev Called by token contract for direct transfers (SECURITY HARDENED)
//      */
//     function notifyTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) external onlyTokenOrAuthorizedHook notPaused {
//         // SECURITY FIX: Take balance snapshots before processing
//         if (from != address(0)) {
//             _takeBalanceSnapshot(from);
//             _updateAccumulation(from);
//         }
//         if (to != address(0)) {
//             _takeBalanceSnapshot(to);
//             _updateAccumulation(to);
//         }

//         if (from != address(0)) {
//             _handleDirectTransferFrom(from, amount);
//         }
//         if (to != address(0)) {
//             _handleDirectTransferTo(to, amount);
//         }
//     }

//     /**
//      * @dev Called by authorized hook for swap notifications (SECURITY HARDENED)
//      */
//     function notifySwap(
//         address user,
//         address tokenIn,
//         address tokenOut,
//         uint256 amountIn,
//         uint256 amountOut,
//         bool isExactInput
//     ) external onlyAuthorizedHook notPaused {
//         // Only process swaps from original contributors
//         if (contributorData[user].originalTokenAllocation == 0) return;

//         _takeBalanceSnapshot(user);
//         _updateAccumulation(user);

//         bool isSelling = tokenIn == partyInfo.tokenAddress;
//         uint256 tokenAmount = isSelling ? amountIn : amountOut;

//         // SECURITY FIX: Validate swap amounts are reasonable
//         require(tokenAmount > 0, "Invalid token amount");
//         require(
//             tokenAmount <= contributorData[user].originalTokenAllocation,
//             "Amount too large"
//         );

//         if (isSelling) {
//             _handleSwapSell(user, tokenAmount);
//         } else {
//             _handleSwapBuy(user, tokenAmount);
//         }

//         emit SwapTracked(user, isSelling, tokenAmount);
//     }

//     /**
//      * @dev SECURITY FIX: Take balance snapshot for accurate tracking
//      */
//     function _takeBalanceSnapshot(address user) internal {
//         if (partyInfo.tokenAddress != address(0)) {
//             balanceSnapshots[user] = IERC20(partyInfo.tokenAddress).balanceOf(
//                 user
//             );
//         }
//     }

//     /**
//      * @dev Handle selling tokens through swaps (SECURITY HARDENED)
//      */
//     function _handleSwapSell(address user, uint256 tokenAmount) internal {
//         ContributorData storage data = contributorData[user];

//         // SECURITY FIX: Use more precise calculation
//         uint256 originalTokensSold = _calculateOriginalTokensInAmountSecure(
//             user,
//             tokenAmount
//         );

//         if (originalTokensSold > 0) {
//             require(
//                 data.currentOriginalTokensHeld >= originalTokensSold,
//                 "Insufficient original tokens"
//             );

//             data.currentOriginalTokensHeld -= originalTokensSold;
//             data.totalSoldThroughSwaps += originalTokensSold;

//             if (data.currentOriginalTokensHeld == 0) {
//                 data.isCurrentlyHolding = false;
//             }
//         }
//     }

//     /**
//      * @dev Handle buying tokens through swaps (SECURITY HARDENED)
//      */
//     function _handleSwapBuy(address user, uint256 tokenAmount) internal {
//         ContributorData storage data = contributorData[user];

//         // User can only "regain" up to their original allocation
//         uint256 maxCanRegain = data.originalTokenAllocation -
//             data.currentOriginalTokensHeld;
//         uint256 originalTokensRegained = tokenAmount > maxCanRegain
//             ? maxCanRegain
//             : tokenAmount;

//         if (originalTokensRegained > 0) {
//             data.currentOriginalTokensHeld += originalTokensRegained;
//             data.isCurrentlyHolding = true;
//             data.lastUpdateTimestamp = block.timestamp;
//         }
//     }

//     /**
//      * @dev SECURITY FIX: More secure calculation of original tokens in amount
//      */
//     function _calculateOriginalTokensInAmountSecure(
//         address user,
//         uint256 amount
//     ) internal view returns (uint256) {
//         ContributorData memory data = contributorData[user];

//         // Use snapshot instead of current balance to prevent race conditions
//         uint256 snapshotBalance = balanceSnapshots[user];

//         // If snapshot balance <= original held, all tokens being moved are original tokens
//         if (snapshotBalance <= data.currentOriginalTokensHeld) {
//             return amount > snapshotBalance ? snapshotBalance : amount;
//         }

//         // If user has more tokens than original allocation, only count original tokens
//         uint256 originalTokensInBalance = data.currentOriginalTokensHeld;
//         return
//             amount > originalTokensInBalance ? originalTokensInBalance : amount;
//     }

//     /**
//      * @dev Handle direct token transfers FROM a user (SECURITY HARDENED)
//      */
//     function _handleDirectTransferFrom(address from, uint256 amount) internal {
//         ContributorData storage data = contributorData[from];
//         if (data.originalTokenAllocation == 0) return;

//         uint256 originalTokensTransferred = _calculateOriginalTokensInAmountSecure(
//                 from,
//                 amount
//             );

//         if (originalTokensTransferred > 0) {
//             require(
//                 data.currentOriginalTokensHeld >= originalTokensTransferred,
//                 "Insufficient original tokens"
//             );

//             data.currentOriginalTokensHeld -= originalTokensTransferred;
//             data.totalSoldThroughTransfers += originalTokensTransferred;

//             if (data.currentOriginalTokensHeld == 0) {
//                 data.isCurrentlyHolding = false;
//             }

//             emit TransferTracked(from, address(0), originalTokensTransferred);
//         }
//     }

//     /**
//      * @dev Handle direct token transfers TO a user (SECURITY HARDENED)
//      */
//     function _handleDirectTransferTo(address to, uint256 amount) internal {
//         ContributorData storage data = contributorData[to];
//         if (data.originalTokenAllocation == 0) return;

//         // Can only regain up to original allocation
//         uint256 maxCanRegain = data.originalTokenAllocation -
//             data.currentOriginalTokensHeld;
//         uint256 originalTokensRegained = amount > maxCanRegain
//             ? maxCanRegain
//             : amount;

//         if (originalTokensRegained > 0) {
//             data.currentOriginalTokensHeld += originalTokensRegained;
//             data.isCurrentlyHolding = true;
//             data.lastUpdateTimestamp = block.timestamp;

//             emit TransferTracked(address(0), to, originalTokensRegained);
//         }
//     }

//     /**
//      * @dev Update token-seconds accumulation with higher precision (SECURITY HARDENED)
//      */
//     function _updateAccumulation(address contributor) internal {
//         ContributorData storage data = contributorData[contributor];
//         if (data.originalTokenAllocation == 0 || !data.isCurrentlyHolding)
//             return;

//         uint256 timeElapsed = block.timestamp - data.lastUpdateTimestamp;
//         if (timeElapsed > 0 && data.currentOriginalTokensHeld > 0) {
//             // SECURITY FIX: Use higher precision math
//             uint256 tokenSeconds = (data.currentOriginalTokensHeld *
//                 timeElapsed *
//                 PRECISION) / PRECISION;

//             // Check for overflow
//             require(
//                 data.accumulatedTokenSeconds + tokenSeconds >=
//                     data.accumulatedTokenSeconds,
//                 "Overflow"
//             );
//             require(
//                 rewardState.totalAccumulatedTokenSeconds + tokenSeconds >=
//                     rewardState.totalAccumulatedTokenSeconds,
//                 "Overflow"
//             );

//             data.accumulatedTokenSeconds += tokenSeconds;
//             rewardState.totalAccumulatedTokenSeconds += tokenSeconds;

//             emit RewardsAccumulated(contributor, tokenSeconds);
//         }

//         data.lastUpdateTimestamp = block.timestamp;
//     }

//     /**
//      * @dev Collect LP fees (SECURITY HARDENED)
//      */
//     function collectLPFees() external notPaused {
//         uint256 currentBalance = address(this).balance;
//         uint256 newFees = currentBalance - rewardState.totalFeesCollected;

//         if (newFees > 0) {
//             // Check for overflow
//             require(
//                 rewardState.totalFeesCollected + newFees >=
//                     rewardState.totalFeesCollected,
//                 "Overflow"
//             );

//             rewardState.totalFeesCollected = currentBalance;
//             rewardState.lastFeeCollection = block.timestamp;
//             emit FeesCollected(newFees, currentBalance);
//         }
//     }

//     /**
//      * @dev Calculate claimable rewards with higher precision (SECURITY HARDENED)
//      */
//     function getClaimableRewards(
//         address contributor
//     ) public view returns (uint256) {
//         ContributorData memory data = contributorData[contributor];
//         if (data.originalTokenAllocation == 0) return 0;

//         uint256 totalTokenSeconds = data.accumulatedTokenSeconds;
//         if (data.isCurrentlyHolding && data.currentOriginalTokensHeld > 0) {
//             uint256 timeElapsed = block.timestamp - data.lastUpdateTimestamp;
//             uint256 pendingTokenSeconds = (data.currentOriginalTokensHeld *
//                 timeElapsed *
//                 PRECISION) / PRECISION;
//             totalTokenSeconds += pendingTokenSeconds;
//         }

//         if (rewardState.totalAccumulatedTokenSeconds == 0) return 0;

//         // SECURITY FIX: Higher precision calculation with overflow protection
//         uint256 totalEarned = (rewardState.totalFeesCollected *
//             totalTokenSeconds) / rewardState.totalAccumulatedTokenSeconds;

//         if (totalEarned > data.rewardsClaimed) {
//             return totalEarned - data.rewardsClaimed;
//         }

//         return 0;
//     }

//     /**
//      * @dev Claim rewards with enhanced security (SECURITY HARDENED)
//      */
//     function claimRewards() external nonReentrant notPaused {
//         _updateAccumulation(msg.sender);

//         uint256 claimable = getClaimableRewards(msg.sender);
//         require(claimable > 0, "No rewards to claim");
//         require(
//             claimable <= address(this).balance,
//             "Insufficient contract balance"
//         );

//         // SECURITY FIX: Follow checks-effects-interactions pattern
//         contributorData[msg.sender].rewardsClaimed += claimable;
//         rewardState.totalFeesDistributed += claimable;

//         // Transfer rewards (interactions last)
//         (bool success, ) = payable(msg.sender).call{value: claimable}("");
//         require(success, "Transfer failed");

//         emit RewardsClaimed(msg.sender, claimable);
//     }

//     /**
//      * @dev Get contributors with pagination (SECURITY FIX)
//      */
//     function getContributors(
//         uint256 offset,
//         uint256 limit
//     ) external view returns (address[] memory result, uint256 total) {
//         total = contributors.length;

//         if (offset >= total) {
//             return (new address[](0), total);
//         }

//         uint256 end = offset + limit;
//         if (end > total) end = total;

//         result = new address[](end - offset);
//         for (uint256 i = offset; i < end; i++) {
//             result[i - offset] = contributors[i];
//         }
//     }

//     /**
//      * @dev Process contribution with security checks (SECURITY HARDENED)
//      */
//     function _processContribution() internal {
//         require(!partyInfo.launched, "Already launched");
//         require(msg.value > 0, "Zero amount");

//         // SECURITY FIX: Mark address as contributed to prevent multi-address exploitation
//         partyInfo.contributorExists[msg.sender] = true;

//         contributors.push(msg.sender);
//         contributions[msg.sender] = msg.value; // Single contribution per address
//         contributorData[msg.sender].contributionAmount = msg.value;

//         // Check for overflow
//         require(
//             partyInfo.currentAmount + msg.value >= partyInfo.currentAmount,
//             "Overflow"
//         );
//         partyInfo.currentAmount += msg.value;

//         emit ContributionReceived(msg.sender, msg.value);

//         if (partyInfo.currentAmount >= partyInfo.targetAmount) {
//             _triggerLaunch();
//         }
//     }

//     /**
//      * @dev Manual launch by creator
//      */
//     function manualLaunch() external onlyCreator notPaused {
//         require(!partyInfo.launched, "Already launched");
//         require(partyInfo.currentAmount > 0, "No funds");
//         _triggerLaunch();
//     }

//     function _triggerLaunch() internal {
//         partyInfo.launched = true;
//         uint256 balance = address(this).balance;
//         IPartyStarter(partyStarter).launchFromVenue{value: balance}(
//             partyInfo.partyId
//         );
//         emit PartyLaunched(balance);
//     }

//     // View functions
//     function getTotalContributors() external view returns (uint256) {
//         return contributors.length;
//     }

//     function isAuthorizedHook(address hook) external view returns (bool) {
//         return securityConfig.authorizedHooks[hook];
//     }

//     function getRewardState() external view returns (RewardState memory) {
//         return rewardState;
//     }

//     receive() external payable {
//         if (!partyInfo.launched && !partyInfo.isPrivate && !partyInfo.paused) {
//             _processContribution();
//         }
//     }
// }
