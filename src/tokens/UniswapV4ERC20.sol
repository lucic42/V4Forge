// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {ERC20} from "solmate/tokens/ERC20.sol";
// import {Owned} from "solmate/auth/Owned.sol";

// /**
//  * @title UniswapV4ERC20
//  * @dev Gas-optimized ERC20 token for Uniswap V4 integration
//  * Enhanced with proper events and access control
//  */
// contract UniswapV4ERC20 is ERC20, Owned {
//     event MintingEnabled(bool enabled);
//     event BurningEnabled(bool enabled);

//     bool public mintingEnabled = true;
//     bool public burningEnabled = true;

//     modifier whenMintingEnabled() {
//         require(mintingEnabled, "Minting disabled");
//         _;
//     }

//     modifier whenBurningEnabled() {
//         require(burningEnabled, "Burning disabled");
//         _;
//     }

//     constructor(
//         string memory name,
//         string memory symbol
//     ) ERC20(name, symbol, 18) Owned(msg.sender) {}

//     /**
//      * @dev Mint tokens to account - Gas optimized
//      * @param account The account to mint tokens to
//      * @param amount The amount of tokens to mint
//      */
//     function mint(
//         address account,
//         uint256 amount
//     ) external onlyOwner whenMintingEnabled {
//         _mint(account, amount);
//     }

//     /**
//      * @dev Burn tokens from account - Gas optimized
//      * @param account The account to burn tokens from
//      * @param amount The amount of tokens to burn
//      */
//     function burn(
//         address account,
//         uint256 amount
//     ) external onlyOwner whenBurningEnabled {
//         _burn(account, amount);
//     }

//     /**
//      * @dev Disable minting permanently (one-way operation)
//      */
//     function disableMinting() external onlyOwner {
//         mintingEnabled = false;
//         emit MintingEnabled(false);
//     }

//     /**
//      * @dev Disable burning permanently (one-way operation)
//      */
//     function disableBurning() external onlyOwner {
//         burningEnabled = false;
//         emit BurningEnabled(false);
//     }

//     /**
//      * @dev Batch transfer to multiple recipients - Gas optimized
//      * @param recipients Array of recipient addresses
//      * @param amounts Array of amounts to transfer
//      */
//     function batchTransfer(
//         address[] calldata recipients,
//         uint256[] calldata amounts
//     ) external returns (bool) {
//         uint256 length = recipients.length;
//         require(length == amounts.length, "Array length mismatch");
//         require(length > 0, "Empty arrays");

//         unchecked {
//             for (uint256 i = 0; i < length; ++i) {
//                 transfer(recipients[i], amounts[i]);
//             }
//         }

//         return true;
//     }
// }
