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
//  * @title PartyVenueFixed
//  * @dev Fixed venue contract that properly tracks original presale allocations and prevents gaming
//  *
//  * KEY FIXES:
//  * 1. Tracks original presale tokens separately from current balance
//  * 2. Locks in rewards when transfers occur (no timing manipulation)
//  * 3. Re-bought tokens don't earn rewards (only original presale allocation)
//  * 4. Uses "original-token-seconds" for accurate weighted time calculations
//  */
// contract PartyVenueFixed is Owned, ReentrancyGuard {
//     using ECDSA for bytes32;
//     using PartyErrors for *;

//     struct PartyInfo {
//         uint256 partyId;
//         address creator;
//         uint256 targetAmount;
//         uint256 currentAmount;
//         bool launched;
//         bool isPrivate;
//         address signerAddress;
//         address tokenAddress;
//         mapping(bytes32 => bool) usedSignatures;
//     }

//     struct ContributorData {
//         uint256 contributionAmount; // Original ETH contribution (never changes)
//         uint256 originalTokenAllocation; // Original presale token allocation (never changes)
//         uint256 currentOriginalTokensHeld; // Current original tokens held (0 to originalTokenAllocation)
//         uint256 accumulatedTokenSeconds; // Accumulated "original-token-seconds"
//         uint256 lastUpdateTimestamp; // Last time accumulation was updated
//         uint256 rewardsClaimed; // Total rewards already claimed
//         bool isCurrentlyHolding; // Whether currently holding any original tokens
//     }

//     struct RewardState {
//         uint256 totalFeesCollected;
//         uint256 totalFeesDistributed;
//         uint256 totalOriginalTokensDistributed;
//         uint256 totalAccumulatedTokenSeconds; // Global sum of all "token-seconds"
//         uint256 lastFeeCollection;
//     }

//     PartyInfo public partyInfo;
//     RewardState public rewardState;
//     address public immutable partyStarter;
//     address[] public contributors;
//     mapping(address => ContributorData) public contributorData;
//     mapping(address => uint256) public contributions; // For backward compatibility

//     // Events
//     event ContributionReceived(address indexed contributor, uint256 amount);
//     event PartyLaunched(uint256 totalAmount);
//     event TokensDistributed(
//         address indexed contributor,
//         uint256 originalAllocation
//     );
//     event OriginalTokensTransferred(
//         address indexed from,
//         address indexed to,
//         uint256 amount
//     );
//     event RewardsAccumulated(address indexed contributor, uint256 tokenSeconds);
//     event RewardsClaimed(address indexed contributor, uint256 amount);
//     event FeesCollected(uint256 newFees, uint256 totalFees);

//     modifier onlyPartyStarter() {
//         require(msg.sender == partyStarter, "Only PartyStarter");
//         _;
//     }

//     modifier onlyCreator() {
//         require(msg.sender == partyInfo.creator, "Only creator");
//         _;
//     }

//     modifier onlyToken() {
//         require(msg.sender == partyInfo.tokenAddress, "Only token");
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
//     }

//     /**
//      * @dev Set the token address after launch
//      */
//     function setTokenAddress(address tokenAddress) external onlyPartyStarter {
//         partyInfo.tokenAddress = tokenAddress;
//     }

//     /**
//      * @dev Contribute ETH to presale
//      */
//     function contribute() external payable nonReentrant {
//         require(!partyInfo.isPrivate, "Private party requires signature");
//         _processContribution();
//     }

//     /**
//      * @dev Distribute original presale tokens - sets immutable allocations
//      */
//     function distributeTokens(
//         address contributor,
//         uint256 tokenAmount
//     ) external onlyPartyStarter {
//         ContributorData storage data = contributorData[contributor];
//         require(data.contributionAmount > 0, "Not a contributor");
//         require(data.originalTokenAllocation == 0, "Already distributed");

//         // Set the original allocation (IMMUTABLE - never changes)
//         data.originalTokenAllocation = tokenAmount;
//         data.currentOriginalTokensHeld = tokenAmount;
//         data.lastUpdateTimestamp = block.timestamp;
//         data.isCurrentlyHolding = true;

//         // Update global state
//         rewardState.totalOriginalTokensDistributed += tokenAmount;

//         emit TokensDistributed(contributor, tokenAmount);
//     }

//     /**
//      * @dev Called by token when transfers occur - tracks original token movements
//      */
//     function notifyTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) external onlyToken {
//         // Update accumulations before processing transfer
//         if (from != address(0)) {
//             _updateAccumulation(from);
//         }
//         if (to != address(0)) {
//             _updateAccumulation(to);
//         }

//         // Process the transfer effects
//         if (from != address(0)) {
//             _handleTransferFrom(from, to, amount);
//         }
//         if (to != address(0)) {
//             _handleTransferTo(to, amount);
//         }
//     }

//     /**
//      * @dev Handle tokens being transferred FROM a contributor
//      */
//     function _handleTransferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) internal {
//         ContributorData storage data = contributorData[from];
//         if (data.originalTokenAllocation == 0) return;

//         // Get current actual token balance
//         uint256 currentBalance = IERC20(partyInfo.tokenAddress).balanceOf(from);

//         // Calculate how many original tokens are being transferred
//         uint256 originalTokensBeingTransferred = 0;

//         if (data.currentOriginalTokensHeld > 0) {
//             // They have original tokens to transfer
//             uint256 originalTokensInBalance = data.currentOriginalTokensHeld;
//             if (currentBalance < originalTokensInBalance) {
//                 // Their balance is less than original tokens held - they must have transferred some already
//                 originalTokensInBalance = currentBalance;
//             }

//             // Amount of original tokens being transferred in this transaction
//             originalTokensBeingTransferred = amount > originalTokensInBalance
//                 ? originalTokensInBalance
//                 : amount;

//             data.currentOriginalTokensHeld -= originalTokensBeingTransferred;

//             if (data.currentOriginalTokensHeld == 0) {
//                 data.isCurrentlyHolding = false;
//             }
//         }

//         emit OriginalTokensTransferred(
//             from,
//             to,
//             originalTokensBeingTransferred
//         );
//     }

//     /**
//      * @dev Handle tokens being transferred TO a contributor
//      */
//     function _handleTransferTo(address to, uint256 amount) internal {
//         ContributorData storage data = contributorData[to];
//         if (data.originalTokenAllocation == 0) return;

//         // Get current actual token balance (after transfer)
//         uint256 currentBalance = IERC20(partyInfo.tokenAddress).balanceOf(to);

//         // They can only "regain" up to their original allocation
//         uint256 maxOriginalTokens = data.originalTokenAllocation;
//         uint256 newOriginalTokensHeld = currentBalance > maxOriginalTokens
//             ? maxOriginalTokens
//             : currentBalance;

//         if (newOriginalTokensHeld > data.currentOriginalTokensHeld) {
//             data.currentOriginalTokensHeld = newOriginalTokensHeld;
//             data.isCurrentlyHolding = true;
//             // Reset timestamp when they regain tokens
//             data.lastUpdateTimestamp = block.timestamp;
//         }
//     }

//     /**
//      * @dev Update token-seconds accumulation for a contributor
//      */
//     function _updateAccumulation(address contributor) internal {
//         ContributorData storage data = contributorData[contributor];
//         if (data.originalTokenAllocation == 0 || !data.isCurrentlyHolding)
//             return;

//         uint256 timeElapsed = block.timestamp - data.lastUpdateTimestamp;
//         if (timeElapsed > 0 && data.currentOriginalTokensHeld > 0) {
//             uint256 tokenSeconds = data.currentOriginalTokensHeld * timeElapsed;
//             data.accumulatedTokenSeconds += tokenSeconds;
//             rewardState.totalAccumulatedTokenSeconds += tokenSeconds;

//             emit RewardsAccumulated(contributor, tokenSeconds);
//         }

//         data.lastUpdateTimestamp = block.timestamp;
//     }

//     /**
//      * @dev Collect LP fees from the pool
//      */
//     function collectLPFees() external {
//         uint256 currentBalance = address(this).balance;
//         uint256 newFees = currentBalance - rewardState.totalFeesCollected;

//         if (newFees > 0) {
//             rewardState.totalFeesCollected = currentBalance;
//             rewardState.lastFeeCollection = block.timestamp;
//             emit FeesCollected(newFees, currentBalance);
//         }
//     }

//     /**
//      * @dev Calculate claimable rewards for a contributor
//      */
//     function getClaimableRewards(
//         address contributor
//     ) public view returns (uint256) {
//         ContributorData memory data = contributorData[contributor];
//         if (data.originalTokenAllocation == 0) return 0;

//         // Calculate current accumulated token-seconds
//         uint256 totalTokenSeconds = data.accumulatedTokenSeconds;
//         if (data.isCurrentlyHolding && data.currentOriginalTokensHeld > 0) {
//             uint256 timeElapsed = block.timestamp - data.lastUpdateTimestamp;
//             totalTokenSeconds += data.currentOriginalTokensHeld * timeElapsed;
//         }

//         // Calculate total accumulated globally (including pending)
//         uint256 globalTokenSeconds = rewardState.totalAccumulatedTokenSeconds;

//         // Add pending accumulations for all active holders
//         // Note: This is an approximation. For exact calculations, call updateAllAccumulations() first

//         if (globalTokenSeconds == 0) return 0;

//         // Calculate share of total fees
//         uint256 totalEarned = (rewardState.totalFeesCollected *
//             totalTokenSeconds) / globalTokenSeconds;

//         // Subtract already claimed
//         if (totalEarned > data.rewardsClaimed) {
//             return totalEarned - data.rewardsClaimed;
//         }

//         return 0;
//     }

//     /**
//      * @dev Claim rewards for the caller
//      */
//     function claimRewards() external nonReentrant {
//         // Update accumulation first
//         _updateAccumulation(msg.sender);

//         uint256 claimable = getClaimableRewards(msg.sender);
//         require(claimable > 0, "No rewards to claim");

//         contributorData[msg.sender].rewardsClaimed += claimable;
//         rewardState.totalFeesDistributed += claimable;

//         (bool success, ) = payable(msg.sender).call{value: claimable}("");
//         require(success, "Transfer failed");

//         emit RewardsClaimed(msg.sender, claimable);
//     }

//     /**
//      * @dev Update accumulations for multiple users (gas-intensive, use carefully)
//      */
//     function updateAccumulations(address[] calldata users) external {
//         for (uint256 i = 0; i < users.length; i++) {
//             _updateAccumulation(users[i]);
//         }
//     }

//     /**
//      * @dev Get detailed contributor information
//      */
//     function getContributorInfo(
//         address contributor
//     )
//         external
//         view
//         returns (
//             uint256 contributionAmount,
//             uint256 originalAllocation,
//             uint256 currentOriginalHeld,
//             uint256 accumulatedTokenSeconds,
//             uint256 claimableRewards,
//             uint256 rewardsClaimed,
//             bool isHolding
//         )
//     {
//         ContributorData memory data = contributorData[contributor];
//         return (
//             data.contributionAmount,
//             data.originalTokenAllocation,
//             data.currentOriginalTokensHeld,
//             data.accumulatedTokenSeconds,
//             getClaimableRewards(contributor),
//             data.rewardsClaimed,
//             data.isCurrentlyHolding
//         );
//     }

//     /**
//      * @dev Manual launch by creator
//      */
//     function manualLaunch() external onlyCreator {
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

//     function _processContribution() internal {
//         require(!partyInfo.launched, "Already launched");
//         require(msg.value > 0, "Zero amount");

//         bool isFirstContribution = contributions[msg.sender] == 0;
//         if (isFirstContribution) {
//             contributors.push(msg.sender);
//         }

//         contributions[msg.sender] += msg.value;
//         contributorData[msg.sender].contributionAmount += msg.value;
//         partyInfo.currentAmount += msg.value;

//         emit ContributionReceived(msg.sender, msg.value);

//         if (partyInfo.currentAmount >= partyInfo.targetAmount) {
//             _triggerLaunch();
//         }
//     }

//     // View functions
//     function getContributors() external view returns (address[] memory) {
//         return contributors;
//     }

//     function getPartyInfo()
//         external
//         view
//         returns (
//             uint256 partyId,
//             address creator,
//             uint256 targetAmount,
//             uint256 currentAmount,
//             bool launched,
//             bool isPrivate,
//             address tokenAddress
//         )
//     {
//         return (
//             partyInfo.partyId,
//             partyInfo.creator,
//             partyInfo.targetAmount,
//             partyInfo.currentAmount,
//             partyInfo.launched,
//             partyInfo.isPrivate,
//             partyInfo.tokenAddress
//         );
//     }

//     function getRewardState() external view returns (RewardState memory) {
//         return rewardState;
//     }

//     receive() external payable {
//         if (!partyInfo.launched && !partyInfo.isPrivate) {
//             _processContribution();
//         }
//     }
// }
