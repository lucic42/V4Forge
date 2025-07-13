// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Owned} from "solmate/auth/Owned.sol";
// import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
// import {PartyErrors} from "../types/PartyErrors.sol";

// interface IPartyStarter {
//     function launchFromVenue(uint256 partyId) external payable;
// }

// /**
//  * @title PartyVenue
//  * @dev Individual contract for collecting funds for a specific public or private party
//  * Each party gets its own venue contract deployed
//  * Supports signature-based authorization for private parties
//  */
// contract PartyVenue is Owned, ReentrancyGuard {
//     using ECDSA for bytes32;
//     using PartyErrors for *;

//     struct PartyInfo {
//         uint256 partyId;
//         address creator;
//         uint256 targetAmount;
//         uint256 currentAmount;
//         bool launched;
//         bool isPrivate;
//         bool timeoutLaunched; // Whether launched via timeout
//         uint256 timeoutDeadline; // When anyone can launch
//         address signerAddress; // Address that signs invitation codes
//         mapping(bytes32 => bool) usedSignatures; // Prevent signature replay
//     }

//     PartyInfo public partyInfo;
//     address public immutable partyStarter;
//     address[] public contributors;
//     mapping(address => uint256) public contributions;

//     event ContributionReceived(address indexed contributor, uint256 amount);
//     event PartyLaunched(uint256 totalAmount);
//     event SignerUpdated(address indexed newSigner);

//     // Enhanced events for comprehensive data capture
//     event ContributionProgress(
//         uint256 indexed partyId,
//         address indexed contributor,
//         uint256 contributionAmount,
//         uint256 totalRaised,
//         uint256 targetAmount,
//         uint8 progressPercentage,
//         uint256 contributorCount,
//         uint256 timestamp
//     );

//     event PartyTargetReached(
//         uint256 indexed partyId,
//         uint256 finalAmount,
//         uint256 targetAmount,
//         uint256 contributorCount,
//         uint256 timestamp
//     );

//     event ContributorAdded(
//         uint256 indexed partyId,
//         address indexed contributor,
//         bool isFirstContribution,
//         uint256 contributorIndex,
//         uint256 timestamp
//     );

//     event PartyTimeoutLaunched(
//         uint256 indexed partyId,
//         address indexed launcher,
//         uint256 ethAmount,
//         uint256 timestamp
//     );

//     modifier onlyPartyStarter() {
//         PartyErrors.requireAuthorized(
//             msg.sender == partyStarter,
//             PartyErrors.ErrorCode.ONLY_PARTY_STARTER
//         );
//         _;
//     }

//     modifier onlyCreator() {
//         PartyErrors.requireAuthorized(
//             msg.sender == partyInfo.creator,
//             PartyErrors.ErrorCode.ONLY_CREATOR
//         );
//         _;
//     }

//     constructor(
//         uint256 _partyId,
//         address _creator,
//         uint256 _targetAmount,
//         bool _isPrivate,
//         address _signerAddress,
//         uint256 _timeoutDeadline
//     ) Owned(_creator) {
//         partyStarter = msg.sender;
//         partyInfo.partyId = _partyId;
//         partyInfo.creator = _creator;
//         partyInfo.targetAmount = _targetAmount;
//         partyInfo.isPrivate = _isPrivate;
//         partyInfo.signerAddress = _signerAddress;
//         partyInfo.timeoutDeadline = _timeoutDeadline;
//     }

//     /**
//      * @dev Contribute ETH to this party (traditional way - public parties only)
//      */
//     function contribute() external payable nonReentrant {
//         PartyErrors.requireValidState(
//             !partyInfo.isPrivate,
//             PartyErrors.ErrorCode.SIGNATURE_REQUIRED
//         );
//         _contribute();
//     }

//     /**
//      * @dev Contribute ETH to this party with signature authorization
//      * @param signature The signature from the backend authorizing this contribution
//      * @param maxAmount The maximum amount this signature authorizes
//      * @param deadline The deadline for this signature
//      */
//     function contributeWithSignature(
//         bytes calldata signature,
//         uint256 maxAmount,
//         uint256 deadline
//     ) external payable nonReentrant {
//         PartyErrors.requireValidState(
//             partyInfo.isPrivate,
//             PartyErrors.ErrorCode.NOT_WHITELISTED
//         );
//         PartyErrors.requireValidState(
//             block.timestamp <= deadline,
//             PartyErrors.ErrorCode.SIGNATURE_EXPIRED
//         );
//         PartyErrors.requireValidState(
//             msg.value <= maxAmount,
//             PartyErrors.ErrorCode.CONTRIBUTION_TOO_HIGH
//         );

//         // Create the message hash
//         bytes32 messageHash = keccak256(
//             abi.encodePacked(
//                 "\x19Ethereum Signed Message:\n32",
//                 keccak256(
//                     abi.encodePacked(
//                         partyInfo.partyId,
//                         msg.sender,
//                         maxAmount,
//                         deadline
//                     )
//                 )
//             )
//         );

//         // Verify the signature hasn't been used
//         PartyErrors.requireValidState(
//             !partyInfo.usedSignatures[messageHash],
//             PartyErrors.ErrorCode.SIGNATURE_ALREADY_USED
//         );

//         // Verify the signature
//         address recoveredSigner = messageHash.recover(signature);
//         PartyErrors.requireValidState(
//             recoveredSigner == partyInfo.signerAddress,
//             PartyErrors.ErrorCode.INVALID_SIGNATURE
//         );

//         // Mark signature as used
//         partyInfo.usedSignatures[messageHash] = true;

//         // Process the contribution
//         _processContribution();
//     }

//     /**
//      * @dev Update the signer address (only creator)
//      */
//     function updateSigner(address newSigner) external onlyCreator {
//         partyInfo.signerAddress = newSigner;
//         emit SignerUpdated(newSigner);
//     }

//     /**
//      * @dev Manual launch by creator (can trigger before target is reached)
//      */
//     function manualLaunch() external onlyCreator {
//         PartyErrors.requireValidState(
//             !partyInfo.launched,
//             PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
//         );

//         PartyErrors.requireNonZero(
//             partyInfo.currentAmount,
//             PartyErrors.ErrorCode.NO_FUNDS_RECEIVED
//         );
//         _triggerLaunch();
//     }

//     /**
//      * @dev Launch party after timeout deadline (anyone can call)
//      */
//     function launchAfterTimeout() external nonReentrant {
//         PartyErrors.requireValidState(
//             !partyInfo.launched,
//             PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
//         );

//         PartyErrors.requireValidState(
//             block.timestamp >= partyInfo.timeoutDeadline,
//             PartyErrors.ErrorCode.LAUNCH_TIME_NOT_REACHED
//         );

//         PartyErrors.requireNonZero(
//             partyInfo.currentAmount,
//             PartyErrors.ErrorCode.NO_FUNDS_RECEIVED
//         );

//         partyInfo.timeoutLaunched = true;

//         // Emit timeout launch event
//         emit PartyTimeoutLaunched(
//             partyInfo.partyId,
//             msg.sender,
//             partyInfo.currentAmount,
//             block.timestamp
//         );

//         _triggerLaunch();
//     }

//     /**
//      * @dev Internal function to trigger launch
//      */
//     function _triggerLaunch() internal {
//         partyInfo.launched = true;

//         // Call PartyStarter to launch with collected funds
//         uint256 balance = address(this).balance;

//         // Cast to interface and call the launch function
//         IPartyStarter(partyStarter).launchFromVenue{value: balance}(
//             partyInfo.partyId
//         );

//         emit PartyLaunched(balance);
//     }

//     /**
//      * @dev Get party information
//      */
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
//             bool timeoutLaunched,
//             uint256 timeoutDeadline,
//             address signerAddress
//         )
//     {
//         return (
//             partyInfo.partyId,
//             partyInfo.creator,
//             partyInfo.targetAmount,
//             partyInfo.currentAmount,
//             partyInfo.launched,
//             partyInfo.isPrivate,
//             partyInfo.timeoutLaunched,
//             partyInfo.timeoutDeadline,
//             partyInfo.signerAddress
//         );
//     }

//     /**
//      * @dev Check if signature has been used
//      */
//     function isSignatureUsed(bytes32 messageHash) external view returns (bool) {
//         return partyInfo.usedSignatures[messageHash];
//     }

//     /**
//      * @dev Get all contributors
//      */
//     function getContributors() external view returns (address[] memory) {
//         return contributors;
//     }

//     /**
//      * @dev Get contribution amount for a specific address
//      */
//     function getContribution(
//         address contributor
//     ) external view returns (uint256) {
//         return contributions[contributor];
//     }

//     /**
//      * @dev Check if timeout launch is available
//      */
//     function canLaunchAfterTimeout() external view returns (bool) {
//         return
//             !partyInfo.launched &&
//             block.timestamp >= partyInfo.timeoutDeadline &&
//             partyInfo.currentAmount > 0;
//     }

//     /**
//      * @dev Allow contract to receive ETH (public parties only)
//      */
//     receive() external payable nonReentrant {
//         PartyErrors.requireValidState(
//             !partyInfo.isPrivate,
//             PartyErrors.ErrorCode.SIGNATURE_REQUIRED
//         );
//         _contribute();
//     }

//     /**
//      * @dev Internal contribute function (public parties only)
//      */
//     function _contribute() internal {
//         PartyErrors.requireValidState(
//             !partyInfo.launched,
//             PartyErrors.ErrorCode.PARTY_ALREADY_LAUNCHED
//         );
//         PartyErrors.requireNonZero(
//             msg.value,
//             PartyErrors.ErrorCode.ZERO_AMOUNT
//         );
//         PartyErrors.requireValidState(
//             !partyInfo.isPrivate,
//             PartyErrors.ErrorCode.SIGNATURE_REQUIRED
//         );

//         _processContribution();
//     }

//     /**
//      * @dev Internal function to process contribution
//      */
//     function _processContribution() internal {
//         // Check if this is a new contributor
//         bool isFirstContribution = contributions[msg.sender] == 0;
//         uint256 contributorIndex = contributors.length;

//         // Track contribution
//         if (isFirstContribution) {
//             contributors.push(msg.sender);
//         }
//         contributions[msg.sender] += msg.value;
//         partyInfo.currentAmount += msg.value;

//         // Calculate progress percentage
//         uint8 progressPercentage = 0;
//         if (partyInfo.targetAmount > 0) {
//             progressPercentage = uint8(
//                 (partyInfo.currentAmount * 100) / partyInfo.targetAmount
//             );
//             if (progressPercentage > 100) progressPercentage = 100;
//         }

//         // Emit basic contribution event
//         emit ContributionReceived(msg.sender, msg.value);

//         // Emit enhanced contribution progress event
//         emit ContributionProgress(
//             partyInfo.partyId,
//             msg.sender,
//             msg.value,
//             partyInfo.currentAmount,
//             partyInfo.targetAmount,
//             progressPercentage,
//             contributors.length,
//             block.timestamp
//         );

//         // Emit contributor added event for new contributors
//         if (isFirstContribution) {
//             emit ContributorAdded(
//                 partyInfo.partyId,
//                 msg.sender,
//                 true,
//                 contributorIndex,
//                 block.timestamp
//             );
//         }

//         // Check if target reached and emit event
//         if (partyInfo.currentAmount >= partyInfo.targetAmount) {
//             emit PartyTargetReached(
//                 partyInfo.partyId,
//                 partyInfo.currentAmount,
//                 partyInfo.targetAmount,
//                 contributors.length,
//                 block.timestamp
//             );
//             _triggerLaunch();
//         }
//     }
// }
