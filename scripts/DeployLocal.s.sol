// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PartyStarterV2} from "../src/PartyStarterV2.sol";
import {PublicPartyVenue} from "../src/PublicPartyVenue.sol";

// Simple WETH9 contract for testing
contract WETH9 {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad, "Insufficient balance");
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) public returns (bool) {
        require(balanceOf[src] >= wad, "Insufficient balance");

        if (
            src != msg.sender && allowance[src][msg.sender] != type(uint256).max
        ) {
            require(
                allowance[src][msg.sender] >= wad,
                "Insufficient allowance"
            );
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);
        return true;
    }
}

// Simple Factory Mock for testing
contract MockFactory {
    mapping(address => mapping(address => mapping(uint24 => address)))
        public getPool;

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool) {
        // For testing purposes, just return a mock address
        pool = address(
            uint160(uint256(keccak256(abi.encodePacked(tokenA, tokenB, fee))))
        );
        getPool[tokenA][tokenB][fee] = pool;
        getPool[tokenB][tokenA][fee] = pool;
        return pool;
    }
}

// Simple Position Manager Mock for testing
contract MockPositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool) {
        // Mock implementation
        return
            address(
                uint160(
                    uint256(keccak256(abi.encodePacked(token0, token1, fee)))
                )
            );
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // Mock implementation
        return (1, 1000, params.amount0Desired, params.amount1Desired);
    }
}

contract DeployLocal is Script {
    address public weth9;
    address public factory;
    address public positionManager;
    address public partyStarterV2;
    address public testPartyVenue;

    function run() external {
        vm.startBroadcast();

        // 1. Deploy WETH9
        deployWETH9();

        // 2. Deploy Mock Factory
        deployFactory();

        // 3. Deploy Mock Position Manager
        deployPositionManager();

        // 4. Deploy PartyStarterV2
        deployPartyStarter();

        // 5. Create a test party venue
        createTestParty();

        vm.stopBroadcast();

        // Log all deployed addresses
        logAddresses();
    }

    function deployWETH9() internal {
        WETH9 wethContract = new WETH9();
        weth9 = address(wethContract);
        console.log("WETH9 deployed at:", weth9);
    }

    function deployFactory() internal {
        MockFactory factoryContract = new MockFactory();
        factory = address(factoryContract);
        console.log("MockFactory deployed at:", factory);
    }

    function deployPositionManager() internal {
        MockPositionManager positionManagerContract = new MockPositionManager();
        positionManager = address(positionManagerContract);
        console.log("MockPositionManager deployed at:", positionManager);
    }

    function deployPartyStarter() internal {
        PartyStarterV2 partyStarter = new PartyStarterV2(
            factory,
            positionManager,
            address(this) // Using deployer as vault for testing
        );
        partyStarterV2 = address(partyStarter);
        console.log("PartyStarterV2 deployed at:", partyStarterV2);
    }

    function createTestParty() internal {
        PartyStarterV2 partyStarter = PartyStarterV2(partyStarterV2);

        testPartyVenue = partyStarter.createParty(
            block.timestamp + 1 days, // timeout
            1 ether, // ethAmount
            1000 * 1e18, // tokenAmount
            0.1 ether // maxEthContribution
        );

        console.log("Test PublicPartyVenue created at:", testPartyVenue);
    }

    function logAddresses() internal view {
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("WETH9:", weth9);
        console.log("Factory:", factory);
        console.log("Position Manager:", positionManager);
        console.log("PartyStarterV2:", partyStarterV2);
        console.log("Test Party Venue:", testPartyVenue);
        console.log("=============================");
    }
}
