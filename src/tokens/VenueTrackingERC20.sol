// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {ERC20} from "solmate/tokens/ERC20.sol";
// import {Owned} from "solmate/auth/Owned.sol";

// interface IPartyVenueWithRewards {
//     function notifyTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) external;
// }

// /**
//  * @title VenueTrackingERC20
//  * @dev ERC20 token that notifies the PartyVenue of transfers to track holding periods for rewards
//  * This enables the venue to accurately calculate holding duration for LP fee distribution
//  */
// contract VenueTrackingERC20 is ERC20, Owned {
//     address public venueAddress; // The PartyVenue that manages rewards for this token
//     bool public trackingEnabled = true;

//     // Events
//     event VenueAddressSet(address indexed venueAddress);
//     event TrackingEnabled(bool enabled);
//     event TransferNotified(
//         address indexed from,
//         address indexed to,
//         uint256 amount
//     );

//     modifier onlyVenue() {
//         require(msg.sender == venueAddress, "Only venue can call");
//         _;
//     }

//     constructor(
//         string memory name,
//         string memory symbol,
//         address _venueAddress
//     ) ERC20(name, symbol, 18) Owned(msg.sender) {
//         venueAddress = _venueAddress;
//         emit VenueAddressSet(_venueAddress);
//     }

//     /**
//      * @dev Set the venue address (only owner)
//      */
//     function setVenueAddress(address _venueAddress) external onlyOwner {
//         venueAddress = _venueAddress;
//         emit VenueAddressSet(_venueAddress);
//     }

//     /**
//      * @dev Enable or disable transfer tracking (only owner)
//      */
//     function setTrackingEnabled(bool _enabled) external onlyOwner {
//         trackingEnabled = _enabled;
//         emit TrackingEnabled(_enabled);
//     }

//     /**
//      * @dev Override transfer to notify venue of holding changes
//      */
//     function transfer(
//         address to,
//         uint256 amount
//     ) public override returns (bool) {
//         _notifyTransfer(msg.sender, to, amount);
//         return super.transfer(to, amount);
//     }

//     /**
//      * @dev Override transferFrom to notify venue of holding changes
//      */
//     function transferFrom(
//         address from,
//         address to,
//         uint256 amount
//     ) public override returns (bool) {
//         _notifyTransfer(from, to, amount);
//         return super.transferFrom(from, to, amount);
//     }

//     /**
//      * @dev Notify venue of transfer for holding tracking
//      */
//     function _notifyTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) internal {
//         if (trackingEnabled && venueAddress != address(0) && amount > 0) {
//             try
//                 IPartyVenueWithRewards(venueAddress).notifyTokenTransfer(
//                     from,
//                     to,
//                     amount
//                 )
//             {
//                 emit TransferNotified(from, to, amount);
//             } catch {
//                 // Silently continue if venue notification fails
//                 // This prevents transfers from failing due to venue issues
//             }
//         }
//     }

//     /**
//      * @dev Override _mint to handle new token holders
//      */
//     function _mint(address to, uint256 amount) internal override {
//         super._mint(to, amount);
//         if (trackingEnabled && venueAddress != address(0) && amount > 0) {
//             _notifyTransfer(address(0), to, amount);
//         }
//     }

//     /**
//      * @dev Override _burn to handle token removal
//      */
//     function _burn(address from, uint256 amount) internal override {
//         super._burn(from, amount);
//         if (trackingEnabled && venueAddress != address(0) && amount > 0) {
//             _notifyTransfer(from, address(0), amount);
//         }
//     }

//     /**
//      * @dev Mint tokens (only owner)
//      */
//     function mint(address account, uint256 amount) external onlyOwner {
//         _mint(account, amount);
//     }

//     /**
//      * @dev Burn tokens (only owner)
//      */
//     function burn(address account, uint256 amount) external onlyOwner {
//         _burn(account, amount);
//     }

//     /**
//      * @dev Batch mint to multiple addresses (gas optimized for presale distribution)
//      */
//     function batchMint(
//         address[] calldata recipients,
//         uint256[] calldata amounts
//     ) external onlyOwner {
//         require(recipients.length == amounts.length, "Array length mismatch");
//         require(recipients.length > 0, "Empty arrays");

//         unchecked {
//             for (uint256 i = 0; i < recipients.length; ++i) {
//                 _mint(recipients[i], amounts[i]);
//             }
//         }
//     }

//     /**
//      * @dev Get holding information for an address (if venue supports it)
//      */
//     function getHoldingInfo(
//         address holder
//     ) external view returns (uint256 balance, bool isTracked) {
//         return (
//             balanceOf[holder],
//             trackingEnabled && venueAddress != address(0)
//         );
//     }

//     /**
//      * @dev Emergency function to force update holding status for a user
//      * This can be called if tracking gets out of sync
//      */
//     function forceUpdateHolding(address holder) external {
//         require(
//             trackingEnabled && venueAddress != address(0),
//             "Tracking not enabled"
//         );

//         // This essentially "transfers" 0 tokens to trigger an update
//         try
//             IPartyVenueWithRewards(venueAddress).notifyTokenTransfer(
//                 holder,
//                 holder,
//                 0
//             )
//         {
//             emit TransferNotified(holder, holder, 0);
//         } catch {
//             revert("Failed to update holding status");
//         }
//     }

//     /**
//      * @dev Batch transfer to multiple recipients (gas optimized)
//      */
//     function batchTransfer(
//         address[] calldata recipients,
//         uint256[] calldata amounts
//     ) external returns (bool) {
//         require(recipients.length == amounts.length, "Array length mismatch");
//         require(recipients.length > 0, "Empty arrays");

//         unchecked {
//             for (uint256 i = 0; i < recipients.length; ++i) {
//                 transfer(recipients[i], amounts[i]);
//             }
//         }

//         return true;
//     }
// }
