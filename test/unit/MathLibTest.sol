// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "../utils/TestBase.sol";
import {MathLib} from "../../src/libraries/MathLib.sol";

contract MathLibTest is TestBase {
    function test_Sqrt_Zero() public pure {
        uint256 result = MathLib.sqrt(0);
        assertEq(result, 0);
    }

    function test_Sqrt_One() public pure {
        uint256 result = MathLib.sqrt(1);
        assertEq(result, 1);
    }

    function test_Sqrt_Four() public pure {
        uint256 result = MathLib.sqrt(4);
        assertEq(result, 2);
    }

    function test_Sqrt_Nine() public pure {
        uint256 result = MathLib.sqrt(9);
        assertEq(result, 3);
    }

    function test_Sqrt_Sixteen() public pure {
        uint256 result = MathLib.sqrt(16);
        assertEq(result, 4);
    }

    function test_Sqrt_Large() public pure {
        uint256 result = MathLib.sqrt(1000000);
        assertGt(result, 999);
        assertLt(result, 1001);
    }

    function test_CalculateBasisPoints_Zero() public {
        uint256 result = MathLib.calculateBasisPoints(1000, 0);
        assertEq(result, 0);
    }

    function test_CalculateBasisPoints_1Percent() public {
        uint256 result = MathLib.calculateBasisPoints(1000, 100); // 1%
        assertEq(result, 10);
    }

    function test_CalculateBasisPoints_10Percent() public {
        uint256 result = MathLib.calculateBasisPoints(1000, 1000); // 10%
        assertEq(result, 100);
    }

    function test_CalculateBasisPoints_50Percent() public {
        uint256 result = MathLib.calculateBasisPoints(1000, 5000); // 50%
        assertEq(result, 500);
    }

    function test_CalculateBasisPoints_100Percent() public {
        uint256 result = MathLib.calculateBasisPoints(1000, 10000); // 100%
        assertEq(result, 1000);
    }

    function test_CalculateFeeDistribution_50_50() public {
        (uint256 devAmount, uint256 platformAmount) = MathLib
            .calculateFeeDistribution(100, 50);
        assertEq(devAmount, 50);
        assertEq(platformAmount, 50);
    }

    function test_CalculateFeeDistribution_30_70() public {
        (uint256 devAmount, uint256 platformAmount) = MathLib
            .calculateFeeDistribution(100, 30);
        assertEq(devAmount, 30);
        assertEq(platformAmount, 70);
    }

    function test_CalculateFeeDistribution_100_0() public {
        (uint256 devAmount, uint256 platformAmount) = MathLib
            .calculateFeeDistribution(100, 100);
        assertEq(devAmount, 100);
        assertEq(platformAmount, 0);
    }

    function test_CalculateFeeDistribution_0_100() public {
        (uint256 devAmount, uint256 platformAmount) = MathLib
            .calculateFeeDistribution(100, 0);
        assertEq(devAmount, 0);
        assertEq(platformAmount, 100);
    }

    function test_CalculateFeeDistribution_InvalidShare_Reverts() public {
        vm.expectRevert(MathLib.InvalidInput.selector);
        MathLib.calculateFeeDistribution(100, 101); // Over 100%
    }

    function test_CalculateSqrtPriceX96_EqualAmounts() public {
        uint256 result = MathLib.calculateSqrtPriceX96(
            1 ether,
            1000 * 1e18,
            true
        );
        assertGt(result, 0);
    }

    function test_CalculateSqrtPriceX96_TokenIsToken0() public {
        uint256 result = MathLib.calculateSqrtPriceX96(
            1 ether,
            1000 * 1e18,
            true
        );
        assertGt(result, 0);
    }

    function test_CalculateSqrtPriceX96_TokenIsToken1() public {
        uint256 result = MathLib.calculateSqrtPriceX96(
            1 ether,
            1000 * 1e18,
            false
        );
        assertGt(result, 0);
    }

    function test_CalculateSqrtPriceX96_ZeroEthAmount_Reverts() public {
        vm.expectRevert(MathLib.InvalidInput.selector);
        MathLib.calculateSqrtPriceX96(0, 1000 * 1e18, true);
    }

    function test_CalculateSqrtPriceX96_ZeroTokenAmount_Reverts() public {
        vm.expectRevert(MathLib.InvalidInput.selector);
        MathLib.calculateSqrtPriceX96(1 ether, 0, true);
    }

    function test_VerySmallValues() public {
        uint256 result = MathLib.calculateBasisPoints(1, 1);
        assertLe(result, 1);
    }

    function test_MaxUint256_Values() public {
        uint256 largeValue = type(uint128).max;
        uint256 result = MathLib.calculateBasisPoints(largeValue, 100); // 1%
        assertEq(result, largeValue / 100);
    }

    function test_Gas_CalculateBasisPoints() public {
        uint256 gasStart = gasleft();
        MathLib.calculateBasisPoints(1000, 500);
        uint256 gasUsed = gasStart - gasleft();
        assertGt(gasUsed, 0);
    }

    function test_Gas_CalculateFeeDistribution() public {
        uint256 gasStart = gasleft();
        MathLib.calculateFeeDistribution(1000, 30);
        uint256 gasUsed = gasStart - gasleft();
        assertGt(gasUsed, 0);
    }

    function test_Gas_Sqrt() public {
        uint256 gasStart = gasleft();
        MathLib.sqrt(1000000);
        uint256 gasUsed = gasStart - gasleft();
        assertGt(gasUsed, 0);
    }

    function test_Gas_CalculateSqrtPriceX96() public {
        uint256 gasStart = gasleft();
        MathLib.calculateSqrtPriceX96(1 ether, 1000 * 1e18, true);
        uint256 gasUsed = gasStart - gasleft();
        assertGt(gasUsed, 0);
    }

    function testFuzz_CalculateBasisPoints(uint256 amount, uint256 bps) public {
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(bps <= 10000); // Max 100%

        uint256 result = MathLib.calculateBasisPoints(amount, bps);
        assertLe(result, amount);
    }

    function testFuzz_CalculateFeeDistribution(
        uint256 totalFees,
        uint256 devShare
    ) public {
        vm.assume(totalFees > 0 && totalFees < type(uint128).max);
        vm.assume(devShare <= 100);

        (uint256 devAmount, uint256 platformAmount) = MathLib
            .calculateFeeDistribution(totalFees, devShare);
        assertEq(devAmount + platformAmount, totalFees);
        assertLe(devAmount, totalFees);
        assertLe(platformAmount, totalFees);
    }

    function testFuzz_Sqrt(uint256 x) public {
        vm.assume(x < type(uint128).max); // Avoid overflow in sqrt calculation

        uint256 result = MathLib.sqrt(x);

        assertLe(result * result, x);
        if (result < type(uint128).max) {
            assertLt(x, (result + 1) * (result + 1));
        }
    }

    function testFuzz_CalculateSqrtPriceX96(
        uint256 ethAmount,
        uint256 tokenAmount,
        bool tokenIsToken0
    ) public {
        vm.assume(ethAmount > 0 && ethAmount < type(uint64).max);
        vm.assume(tokenAmount > 0 && tokenAmount < type(uint64).max);

        // Since MathLib functions are internal, we test with reasonable bounds
        uint256 result = MathLib.calculateSqrtPriceX96(
            ethAmount,
            tokenAmount,
            tokenIsToken0
        );
        assertGt(result, 0);
    }
}
