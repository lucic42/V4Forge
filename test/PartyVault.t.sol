// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PartyVault} from "../src/vault/PartyVault.sol";
import {UniswapV4ERC20} from "../src/tokens/UniswapV4ERC20.sol";

contract PartyVaultTest is Test {
    PartyVault public partyVault;
    UniswapV4ERC20 public token1;
    UniswapV4ERC20 public token2;
    UniswapV4ERC20 public token3;

    address public owner;
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public nonOwner = address(0x3);

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

    function setUp() public {
        owner = address(this);

        // Deploy PartyVault
        partyVault = new PartyVault();

        // Deploy test tokens
        token1 = new UniswapV4ERC20("Token1", "TK1");
        token2 = new UniswapV4ERC20("Token2", "TK2");
        token3 = new UniswapV4ERC20("Token3", "TK3");

        // Mint tokens for testing
        token1.mint(owner, 1000 * 10 ** 18);
        token2.mint(owner, 2000 * 10 ** 18);
        token3.mint(owner, 3000 * 10 ** 18);

        token1.mint(user1, 500 * 10 ** 18);
        token2.mint(user2, 750 * 10 ** 18);
    }

    function testDeployment() public {
        assertEq(partyVault.owner(), owner);
        assertEq(partyVault.getTokenCount(), 0);

        address[] memory tokens = partyVault.getAllTokens();
        assertEq(tokens.length, 0);
    }

    function testReceiveTokens() public {
        uint256 amount = 100 * 10 ** 18;

        // Approve vault to receive tokens
        token1.approve(address(partyVault), amount);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit TokenReceived(address(token1), amount, owner);

        // Receive tokens
        partyVault.receiveTokens(address(token1), amount);

        // Check balances
        assertEq(partyVault.getTokenBalance(address(token1)), amount);
        assertEq(partyVault.getTokenCount(), 1);
        assertEq(token1.balanceOf(address(partyVault)), amount);

        // Check token is in the list
        address[] memory tokens = partyVault.getAllTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(token1));
    }

    function testReceiveMultipleTokens() public {
        uint256 amount1 = 100 * 10 ** 18;
        uint256 amount2 = 200 * 10 ** 18;
        uint256 amount3 = 300 * 10 ** 18;

        // Approve and receive first token
        token1.approve(address(partyVault), amount1);
        partyVault.receiveTokens(address(token1), amount1);

        // Approve and receive second token
        token2.approve(address(partyVault), amount2);
        partyVault.receiveTokens(address(token2), amount2);

        // Approve and receive third token
        token3.approve(address(partyVault), amount3);
        partyVault.receiveTokens(address(token3), amount3);

        // Check all balances
        assertEq(partyVault.getTokenBalance(address(token1)), amount1);
        assertEq(partyVault.getTokenBalance(address(token2)), amount2);
        assertEq(partyVault.getTokenBalance(address(token3)), amount3);
        assertEq(partyVault.getTokenCount(), 3);

        // Check all tokens are in the list
        address[] memory tokens = partyVault.getAllTokens();
        assertEq(tokens.length, 3);
        assertEq(tokens[0], address(token1));
        assertEq(tokens[1], address(token2));
        assertEq(tokens[2], address(token3));
    }

    function testReceiveSameTokenMultipleTimes() public {
        uint256 amount1 = 100 * 10 ** 18;
        uint256 amount2 = 150 * 10 ** 18;

        // First deposit
        token1.approve(address(partyVault), amount1);
        partyVault.receiveTokens(address(token1), amount1);

        // Second deposit of same token
        token1.approve(address(partyVault), amount2);
        partyVault.receiveTokens(address(token1), amount2);

        // Check accumulated balance
        assertEq(
            partyVault.getTokenBalance(address(token1)),
            amount1 + amount2
        );
        assertEq(partyVault.getTokenCount(), 1); // Still only one unique token

        // Check only one entry in tokens array
        address[] memory tokens = partyVault.getAllTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(token1));
    }

    function testReceiveTokensFromDifferentSenders() public {
        uint256 amount1 = 100 * 10 ** 18;
        uint256 amount2 = 200 * 10 ** 18;

        // Owner receives tokens
        token1.approve(address(partyVault), amount1);
        partyVault.receiveTokens(address(token1), amount1);

        // User1 receives tokens
        vm.startPrank(user1);
        token1.approve(address(partyVault), amount2);

        vm.expectEmit(true, true, true, true);
        emit TokenReceived(address(token1), amount2, user1);

        partyVault.receiveTokens(address(token1), amount2);
        vm.stopPrank();

        // Check total balance
        assertEq(
            partyVault.getTokenBalance(address(token1)),
            amount1 + amount2
        );
        assertEq(partyVault.getTokenCount(), 1);
    }

    function testWithdrawTokens() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 withdrawAmount = 300 * 10 ** 18;

        // Deposit tokens
        token1.approve(address(partyVault), depositAmount);
        partyVault.receiveTokens(address(token1), depositAmount);

        uint256 initialBalance = token1.balanceOf(user1);

        // Expect event
        vm.expectEmit(true, true, true, true);
        emit TokenWithdrawn(address(token1), withdrawAmount, user1);

        // Withdraw tokens
        partyVault.withdrawTokens(address(token1), withdrawAmount, user1);

        // Check balances
        assertEq(
            partyVault.getTokenBalance(address(token1)),
            depositAmount - withdrawAmount
        );
        assertEq(token1.balanceOf(user1), initialBalance + withdrawAmount);
        assertEq(
            token1.balanceOf(address(partyVault)),
            depositAmount - withdrawAmount
        );
    }

    function testWithdrawAllTokens() public {
        uint256 amount = 500 * 10 ** 18;

        // Deposit tokens
        token1.approve(address(partyVault), amount);
        partyVault.receiveTokens(address(token1), amount);

        // Withdraw all tokens
        partyVault.withdrawTokens(address(token1), amount, user1);

        // Check balances
        assertEq(partyVault.getTokenBalance(address(token1)), 0);
        assertEq(token1.balanceOf(user1), 500 * 10 ** 18 + amount); // user1 had initial balance
        assertEq(token1.balanceOf(address(partyVault)), 0);
    }

    function testPartialWithdraws() public {
        uint256 amount = 1000 * 10 ** 18;

        // Deposit tokens
        token1.approve(address(partyVault), amount);
        partyVault.receiveTokens(address(token1), amount);

        // Multiple partial withdraws
        partyVault.withdrawTokens(address(token1), 300 * 10 ** 18, user1);
        assertEq(partyVault.getTokenBalance(address(token1)), 700 * 10 ** 18);

        partyVault.withdrawTokens(address(token1), 200 * 10 ** 18, user2);
        assertEq(partyVault.getTokenBalance(address(token1)), 500 * 10 ** 18);

        partyVault.withdrawTokens(address(token1), 500 * 10 ** 18, owner);
        assertEq(partyVault.getTokenBalance(address(token1)), 0);
    }

    function testReceiveTokensRevertsOnZeroAddress() public {
        vm.expectRevert("Invalid token address");
        partyVault.receiveTokens(address(0), 100);
    }

    function testReceiveTokensRevertsOnZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        partyVault.receiveTokens(address(token1), 0);
    }

    function testReceiveTokensRevertsOnInsufficientAllowance() public {
        vm.expectRevert(); // ERC20 transfer will revert
        partyVault.receiveTokens(address(token1), 100 * 10 ** 18);
    }

    function testWithdrawTokensRevertsOnInsufficientBalance() public {
        uint256 amount = 100 * 10 ** 18;

        // Deposit some tokens
        token1.approve(address(partyVault), amount);
        partyVault.receiveTokens(address(token1), amount);

        // Try to withdraw more than available
        vm.expectRevert("Insufficient balance");
        partyVault.withdrawTokens(address(token1), amount + 1, user1);
    }

    function testWithdrawTokensRevertsOnZeroRecipient() public {
        uint256 amount = 100 * 10 ** 18;

        // Deposit tokens
        token1.approve(address(partyVault), amount);
        partyVault.receiveTokens(address(token1), amount);

        // Try to withdraw to zero address
        vm.expectRevert("Invalid recipient address");
        partyVault.withdrawTokens(address(token1), amount, address(0));
    }

    function testWithdrawTokensRevertsOnNonOwner() public {
        uint256 amount = 100 * 10 ** 18;

        // Deposit tokens
        token1.approve(address(partyVault), amount);
        partyVault.receiveTokens(address(token1), amount);

        // Try to withdraw as non-owner
        vm.startPrank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        partyVault.withdrawTokens(address(token1), amount, user1);
        vm.stopPrank();
    }

    function testGetTokenBalanceForNonExistentToken() public {
        assertEq(partyVault.getTokenBalance(address(token1)), 0);
        assertEq(partyVault.getTokenBalance(address(0x999)), 0);
    }

    function testGetAllTokensWhenEmpty() public {
        address[] memory tokens = partyVault.getAllTokens();
        assertEq(tokens.length, 0);
    }

    function testComplexScenario() public {
        // Multiple users depositing multiple tokens
        uint256 amount1 = 100 * 10 ** 18;
        uint256 amount2 = 200 * 10 ** 18;
        uint256 amount3 = 300 * 10 ** 18;

        // Owner deposits token1
        token1.approve(address(partyVault), amount1);
        partyVault.receiveTokens(address(token1), amount1);

        // User1 deposits token1 (same token)
        vm.startPrank(user1);
        token1.approve(address(partyVault), amount2);
        partyVault.receiveTokens(address(token1), amount2);
        vm.stopPrank();

        // User2 deposits token2 (different token)
        vm.startPrank(user2);
        token2.approve(address(partyVault), amount3);
        partyVault.receiveTokens(address(token2), amount3);
        vm.stopPrank();

        // Check state
        assertEq(partyVault.getTokenCount(), 2);
        assertEq(
            partyVault.getTokenBalance(address(token1)),
            amount1 + amount2
        );
        assertEq(partyVault.getTokenBalance(address(token2)), amount3);

        address[] memory tokens = partyVault.getAllTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], address(token1));
        assertEq(tokens[1], address(token2));

        // Partial withdrawals
        partyVault.withdrawTokens(address(token1), 150 * 10 ** 18, user1);
        partyVault.withdrawTokens(address(token2), 100 * 10 ** 18, user2);

        // Check final state
        assertEq(partyVault.getTokenBalance(address(token1)), 150 * 10 ** 18);
        assertEq(partyVault.getTokenBalance(address(token2)), 200 * 10 ** 18);
    }

    function testOwnershipTransfer() public {
        // Transfer ownership
        partyVault.transferOwnership(user1);

        // Old owner shouldn't be able to withdraw
        uint256 amount = 100 * 10 ** 18;
        token1.approve(address(partyVault), amount);
        partyVault.receiveTokens(address(token1), amount);

        vm.expectRevert("UNAUTHORIZED");
        partyVault.withdrawTokens(address(token1), amount, user2);

        // New owner should be able to withdraw
        vm.startPrank(user1);
        partyVault.withdrawTokens(address(token1), amount, user2);
        vm.stopPrank();

        assertEq(partyVault.getTokenBalance(address(token1)), 0);
    }

    function testLargeAmounts() public {
        uint256 largeAmount = type(uint256).max / 2; // Avoid overflow

        // Mint large amount to owner
        token1.mint(owner, largeAmount);

        // Deposit large amount
        token1.approve(address(partyVault), largeAmount);
        partyVault.receiveTokens(address(token1), largeAmount);

        assertEq(partyVault.getTokenBalance(address(token1)), largeAmount);

        // Withdraw large amount
        partyVault.withdrawTokens(address(token1), largeAmount, user1);
        assertEq(partyVault.getTokenBalance(address(token1)), 0);
        assertEq(token1.balanceOf(user1), 500 * 10 ** 18 + largeAmount);
    }

    function testEventEmissions() public {
        uint256 amount = 100 * 10 ** 18;

        // Test TokenReceived event
        token1.approve(address(partyVault), amount);

        vm.expectEmit(true, true, true, true);
        emit TokenReceived(address(token1), amount, owner);
        partyVault.receiveTokens(address(token1), amount);

        // Test TokenWithdrawn event
        vm.expectEmit(true, true, true, true);
        emit TokenWithdrawn(address(token1), amount, user1);
        partyVault.withdrawTokens(address(token1), amount, user1);
    }
}
