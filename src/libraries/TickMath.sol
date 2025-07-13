// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity >=0.7.5;

// /// @title Math library for computing sqrt prices from ticks and vice versa
// /// @notice Computes sqrt price for ticks to prevent manipulation of tick liquidity incentives
// library TickMath {
//     /// @dev The minimum tick that may be used on any pool.
//     int24 internal constant MIN_TICK = -887272;
//     /// @dev The maximum tick that may be used on any pool.
//     int24 internal constant MAX_TICK = -MIN_TICK;

//     /// @notice Calculates sqrt(1.0001^tick) * 2^96
//     /// @param tick The input tick for the calculation
//     /// @return sqrtPriceX96 The sqrt price corresponding to the given tick
//     function getSqrtRatioAtTick(
//         int24 tick
//     ) internal pure returns (uint160 sqrtPriceX96) {
//         uint256 absTick = tick < 0
//             ? uint256(-int256(tick))
//             : uint256(int256(tick));
//         require(absTick <= uint256(MAX_TICK), "T");

//         uint256 ratio = absTick & 0x1 != 0
//             ? 0xfffcb933bd6a884074f7d1391d57de82
//             : 0x100000000000000000000000000000000;
//         if (absTick & 0x2 != 0)
//             ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
//         if (absTick & 0x4 != 0)
//             ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
//         if (absTick & 0x8 != 0)
//             ratio = (ratio * 0xffe5caca7e10e4e61c36248dc0491d62) >> 128;
//         if (absTick & 0x10 != 0)
//             ratio = (ratio * 0xffcb9843d60f815969dbdd0830234648) >> 128;
//         if (absTick & 0x20 != 0)
//             ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
//         if (absTick & 0x40 != 0)
//             ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
//         if (absTick & 0x80 != 0)
//             ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
//         if (absTick & 0x100 != 0)
//             ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
//         if (absTick & 0x200 != 0)
//             ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
//         if (absTick & 0x400 != 0)
//             ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
//         if (absTick & 0x800 != 0)
//             ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e0481d) >> 128;
//         if (absTick & 0x1000 != 0)
//             ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
//         if (absTick & 0x2000 != 0)
//             ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
//         if (absTick & 0x4000 != 0)
//             ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
//         if (absTick & 0x8000 != 0)
//             ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
//         if (absTick & 0x10000 != 0)
//             ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
//         if (absTick & 0x20000 != 0)
//             ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
//         if (absTick & 0x40000 != 0)
//             ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
//         if (absTick & 0x80000 != 0)
//             ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

//         if (tick > 0) ratio = type(uint256).max / ratio;

//         // this divides by 1<<96
//         sqrtPriceX96 = uint160(ratio >> 32);
//     }
// }
