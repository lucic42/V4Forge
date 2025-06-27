// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

/**
 * @title PartyVault
 * @dev A vault contract that receives 1% supply of every token launched through the platform
 */
contract PartyVault is Owned {
    event TokenReceived(
        address indexed token,
        uint256 amount,
        address indexed from
    );
    event TokenWithdrawn(
        address indexed token,
        uint256 amount,
        address indexed to
    );

    mapping(address => uint256) public tokenBalances;
    address[] public tokens;

    constructor() Owned(msg.sender) {}

    /**
     * @dev Receives tokens from launched parties
     * @param token The token address
     * @param amount The amount of tokens to receive
     */
    function receiveTokens(address token, uint256 amount) external {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        // Transfer tokens to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Update balance tracking
        if (tokenBalances[token] == 0) {
            tokens.push(token);
        }
        tokenBalances[token] += amount;

        emit TokenReceived(token, amount, msg.sender);
    }

    /**
     * @dev Allows owner to withdraw accumulated tokens
     * @param token The token address to withdraw
     * @param amount The amount to withdraw
     * @param to The address to send tokens to
     */
    function withdrawTokens(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner {
        require(tokenBalances[token] >= amount, "Insufficient balance");
        require(to != address(0), "Invalid recipient address");

        tokenBalances[token] -= amount;
        IERC20(token).transfer(to, amount);

        emit TokenWithdrawn(token, amount, to);
    }

    /**
     * @dev Get the number of different tokens in the vault
     */
    function getTokenCount() external view returns (uint256) {
        return tokens.length;
    }

    /**
     * @dev Get token balance for a specific token
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    /**
     * @dev Get all tokens in the vault
     */
    function getAllTokens() external view returns (address[] memory) {
        return tokens;
    }
}
