// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {PartyTypes} from "../types/PartyTypes.sol";
import {MathLib} from "./MathLib.sol";
import {UniswapV3ERC20} from "../tokens/UniswapV3ERC20.sol";

/**
 * @title PoolV3Lib
 * @dev Library for Uniswap V3 pool management
 */
library PoolV3Lib {
    event PoolCreated(
        uint256 indexed partyId,
        address indexed poolAddress,
        address indexed tokenAddress,
        uint160 sqrtPriceX96
    );

    event LiquidityAdded(
        uint256 indexed partyId,
        address indexed poolAddress,
        uint256 tokenId,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint128 liquidity
    );

    /**
     * @dev Create a V3 pool for a token pair with WETH
     * @param factory The Uniswap V3 factory contract
     * @param tokenAddress The token address
     * @param weth The WETH address
     * @param fee The fee tier for the pool
     * @return poolAddress The created pool address
     */
    function createPool(
        IUniswapV3Factory factory,
        address tokenAddress,
        address weth,
        uint24 fee
    ) internal returns (address poolAddress) {
        // Create pool if it doesn't exist
        poolAddress = factory.getPool(tokenAddress, weth, fee);

        if (poolAddress == address(0)) {
            poolAddress = factory.createPool(tokenAddress, weth, fee);
        }

        return poolAddress;
    }

    /**
     * @dev Initialize a V3 pool with initial price
     * @param poolAddress The pool address
     * @param tokenAddress The token address
     * @param weth The WETH address
     * @param tokenAmount Amount of tokens for price calculation
     * @param ethAmount Amount of ETH for price calculation
     * @return sqrtPriceX96 The calculated sqrt price
     */
    function initializePool(
        address poolAddress,
        address tokenAddress,
        address weth,
        uint256 tokenAmount,
        uint256 ethAmount
    ) internal returns (uint160 sqrtPriceX96) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        // Calculate initial price
        bool tokenIsToken0 = tokenAddress < weth;
        sqrtPriceX96 = MathLib.calculateSqrtPriceX96(
            tokenAmount,
            ethAmount,
            tokenIsToken0
        );

        // Try to initialize the pool (will revert if already initialized)
        try pool.initialize(sqrtPriceX96) {
            // Pool initialized successfully
        } catch {
            // Pool already initialized, get current price
            (sqrtPriceX96, , , , , , ) = pool.slot0();
        }

        return sqrtPriceX96;
    }

    /**
     * @dev Add liquidity to a V3 pool using the NonfungiblePositionManager
     * @param positionManager The NonfungiblePositionManager contract
     * @param tokenAddress The token address
     * @param weth The WETH address
     * @param fee The fee tier
     * @param tokenAmount Amount of tokens to add
     * @param ethAmount Amount of ETH to add
     * @param recipient The recipient of the LP NFT
     * @return tokenId The NFT token ID
     * @return liquidity The amount of liquidity added
     * @return amount0 The amount of token0 used
     * @return amount1 The amount of token1 used
     */
    function addLiquidity(
        INonfungiblePositionManager positionManager,
        address tokenAddress,
        address weth,
        uint24 fee,
        uint256 tokenAmount,
        uint256 ethAmount,
        address recipient
    )
        internal
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // Determine token order
        (address token0, address token1) = tokenAddress < weth
            ? (tokenAddress, weth)
            : (weth, tokenAddress);

        (uint256 amount0Desired, uint256 amount1Desired) = tokenAddress < weth
            ? (tokenAmount, ethAmount)
            : (ethAmount, tokenAmount);

        // Approve tokens for position manager
        IERC20(token0).approve(address(positionManager), amount0Desired);
        IERC20(token1).approve(address(positionManager), amount1Desired);

        // Create mint parameters for full range liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: PartyTypes.MIN_TICK,
                tickUpper: PartyTypes.MAX_TICK,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0, // Accept any amount of token0
                amount1Min: 0, // Accept any amount of token1
                recipient: recipient,
                deadline: block.timestamp + 300 // 5 minutes
            });

        // Mint the position
        (tokenId, liquidity, amount0, amount1) = positionManager.mint(params);

        return (tokenId, liquidity, amount0, amount1);
    }

    /**
     * @dev Create pool and add initial liquidity
     * @param factory The Uniswap V3 factory
     * @param positionManager The NonfungiblePositionManager
     * @param tokenAddress The token address
     * @param weth The WETH address
     * @param fee The fee tier
     * @param tokenAmount Amount of tokens
     * @param ethAmount Amount of ETH
     * @param recipient The recipient of the LP NFT
     * @param partyId The party ID for events
     * @return poolAddress The pool address
     * @return tokenId The NFT token ID
     * @return liquidity The amount of liquidity added
     */
    function createPoolAndAddLiquidity(
        IUniswapV3Factory factory,
        INonfungiblePositionManager positionManager,
        address tokenAddress,
        address weth,
        uint24 fee,
        uint256 tokenAmount,
        uint256 ethAmount,
        address recipient,
        uint256 partyId
    )
        internal
        returns (address poolAddress, uint256 tokenId, uint128 liquidity)
    {
        // Create pool
        poolAddress = createPool(factory, tokenAddress, weth, fee);

        // Initialize pool with price
        uint160 sqrtPriceX96 = initializePool(
            poolAddress,
            tokenAddress,
            weth,
            tokenAmount,
            ethAmount
        );

        // Add liquidity
        uint256 amount0;
        uint256 amount1;
        (tokenId, liquidity, amount0, amount1) = addLiquidity(
            positionManager,
            tokenAddress,
            weth,
            fee,
            tokenAmount,
            ethAmount,
            recipient
        );

        emit PoolCreated(partyId, poolAddress, tokenAddress, sqrtPriceX96);
        emit LiquidityAdded(
            partyId,
            poolAddress,
            tokenId,
            tokenAmount,
            ethAmount,
            liquidity
        );

        return (poolAddress, tokenId, liquidity);
    }

    function createPoolAndAddOneSidedLiquidity(
        IUniswapV3Factory factory,
        INonfungiblePositionManager positionManager,
        address tokenAddress,
        address weth,
        uint24 fee,
        uint256 tokenAmount,
        address recipient,
        uint256 partyId
    )
        internal
        returns (address poolAddress, uint256 tokenId, uint128 liquidity)
    {
        bool tokenIsToken0 = tokenAddress < weth;
        (address token0, address token1) = tokenIsToken0
            ? (tokenAddress, weth)
            : (weth, tokenAddress);

        // Approve token for position manager
        IERC20(token0).approve(address(positionManager), tokenAmount);

        // Values from Klik contract
        uint160 sqrtPriceX96 = tokenIsToken0
            ? 3068365595550320841079178
            : 2045645379722529521098596513701367;

        poolAddress = positionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            fee,
            sqrtPriceX96
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: PartyTypes.MIN_TICK,
                tickUpper: PartyTypes.MAX_TICK,
                amount0Desired: tokenIsToken0 ? tokenAmount : 0,
                amount1Desired: tokenIsToken0 ? 0 : tokenAmount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: recipient,
                deadline: block.timestamp
            });

        // Mint the position
        uint256 amount0;
        uint256 amount1;
        (tokenId, liquidity, amount0, amount1) = positionManager.mint(params);

        emit PoolCreated(partyId, poolAddress, tokenAddress, sqrtPriceX96);
        emit LiquidityAdded(
            partyId,
            poolAddress,
            tokenId,
            tokenAmount,
            0,
            liquidity
        );

        return (poolAddress, tokenId, liquidity);
    }

    /**
     * @dev Create LP position data structure
     * @param poolAddress The pool address
     * @param tokenAddress The token address
     * @param tokenId The NFT token ID
     * @param fee The fee tier
     * @param liquidity The amount of liquidity
     * @return position The LP position structure
     */
    function createLPPosition(
        address poolAddress,
        address tokenAddress,
        uint256 tokenId,
        uint24 fee,
        uint128 liquidity
    ) internal pure returns (PartyTypes.LPPosition memory position) {
        position = PartyTypes.LPPosition({
            poolAddress: poolAddress,
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            fee: fee,
            tickLower: PartyTypes.MIN_TICK,
            tickUpper: PartyTypes.MAX_TICK,
            liquidity: liquidity,
            feesClaimable: true
        });
    }

    /**
     * @dev Collect fees from a liquidity position
     * @param positionManager The NonfungiblePositionManager
     * @param tokenId The NFT token ID
     * @param recipient The recipient of the fees
     * @return amount0 The amount of token0 collected
     * @return amount1 The amount of token1 collected
     */
    function collectFees(
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        address recipient
    ) internal returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = positionManager.collect(params);
    }

    /**
     * @dev Validate pool creation parameters
     * @param tokenAddress The token address
     * @param weth The WETH address
     * @param ethAmount The ETH amount
     * @param tokenAmount The token amount
     */
    function validatePoolParameters(
        address tokenAddress,
        address weth,
        uint256 ethAmount,
        uint256 tokenAmount
    ) internal pure {
        require(tokenAddress != address(0), "Invalid token address");
        require(weth != address(0), "Invalid WETH address");
        require(tokenAddress != weth, "Token cannot be WETH");
        require(ethAmount > 0, "ETH amount must be greater than 0");
        require(tokenAmount > 0, "Token amount must be greater than 0");
    }
}
