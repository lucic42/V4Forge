// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Import system contracts
import {PartyStarter} from "../../src/PartyStarter.sol";
import {PartyVault} from "../../src/vault/PartyVault.sol";
import {PartyVenue} from "../../src/venue/PartyVenue.sol";
import {EarlySwapLimitHook} from "../../src/hooks/EarlySwapLimitHook.sol";
import {UniswapV4ERC20} from "../../src/tokens/UniswapV4ERC20.sol";

// Import types and libraries
import {PartyTypes} from "../../src/types/PartyTypes.sol";
import {IPartyStarter} from "../../src/interfaces/IPartyStarter.sol";

// Import Uniswap V4 core interfaces
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

// Import HookMiner for proper hook deployment
import {HookMiner} from "./HookMiner.sol";
import {PartyStarterWithHook} from "./PartyStarterWithHook.sol";
import {PartyStarterWithMockHook} from "./PartyStarterWithMockHook.sol";

// Mock contracts for testing
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockValidHook} from "./MockValidHook.sol";

/**
 * @title TestBase
 * @dev Base contract for all tests with common setup and utilities
 */
contract TestBase is Test {
    // Core system contracts
    PartyStarterWithHook public partyStarter;
    PartyVault public partyVault;
    EarlySwapLimitHook public swapLimitHook;
    IPoolManager public poolManager;

    // Mock WETH for testing
    MockERC20 public weth;

    // Test addresses
    address public constant TREASURY = address(0x1234);
    address public constant ALICE = address(0x2001);
    address public constant BOB = address(0x2002);
    address public constant CHARLIE = address(0x2003);
    address public constant DEPLOYER = address(0x1001);

    // Test constants
    uint256 public constant INITIAL_ETH_BALANCE = 100 ether;
    uint256 public constant PARTY_ETH_AMOUNT = 1 ether;

    // Gas tracking
    uint256 public gasUsed;
    uint256 public gasStart;

    // Events for testing
    event PartyCreated(
        uint256 indexed partyId,
        PartyTypes.PartyType indexed partyType,
        address indexed creator,
        PartyTypes.TokenMetadata metadata
    );

    event PartyLaunched(
        uint256 indexed partyId,
        address indexed tokenAddress,
        PoolId indexed poolId,
        uint256 totalLiquidity
    );

    function setUp() public virtual {
        // Set up test environment
        vm.startPrank(DEPLOYER);

        // Deploy mock WETH
        weth = new MockERC20("Wrapped Ether", "WETH", 18);

        // Deploy Uniswap V4 PoolManager
        poolManager = new PoolManager(500000); // 500k gas limit

        // Deploy PartyVault
        partyVault = new PartyVault();

        // Create a simple mock hook for testing
        // We'll use a pre-deployed hook at a known valid address
        MockValidHook mockHook = new MockValidHook(poolManager);
        swapLimitHook = EarlySwapLimitHook(address(mockHook));

        // Deploy PartyStarter with the mock hook
        partyStarter = new PartyStarterWithMockHook(
            poolManager,
            partyVault,
            address(weth),
            TREASURY,
            swapLimitHook
        );

        vm.stopPrank();

        // Give test addresses initial ETH balances
        vm.deal(ALICE, INITIAL_ETH_BALANCE);
        vm.deal(BOB, INITIAL_ETH_BALANCE);
        vm.deal(CHARLIE, INITIAL_ETH_BALANCE);
        vm.deal(DEPLOYER, INITIAL_ETH_BALANCE);
    }

    // ============ Test Utilities ============

    /**
     * @dev Create sample token metadata for testing
     */
    function createTokenMetadata(
        string memory name,
        string memory symbol
    ) public pure returns (PartyTypes.TokenMetadata memory) {
        return
            PartyTypes.TokenMetadata({
                name: name,
                symbol: symbol,
                description: "Test token description",
                image: "https://example.com/image.png",
                website: "https://example.com",
                twitter: "https://twitter.com/test",
                telegram: "https://t.me/test"
            });
    }

    /**
     * @dev Create default token metadata
     */
    function createDefaultMetadata()
        public
        pure
        returns (PartyTypes.TokenMetadata memory)
    {
        return createTokenMetadata("Test Token", "TEST");
    }

    /**
     * @dev Create whitelist for private parties
     */
    function createWhitelist() public pure returns (address[] memory) {
        address[] memory whitelist = new address[](3);
        whitelist[0] = ALICE;
        whitelist[1] = BOB;
        whitelist[2] = CHARLIE;
        return whitelist;
    }

    /**
     * @dev Start gas measurement
     */
    function startMeasureGas() public {
        gasStart = gasleft();
    }

    /**
     * @dev End gas measurement and return gas used
     */
    function endMeasureGas() public returns (uint256) {
        gasUsed = gasStart - gasleft();
        return gasUsed;
    }

    /**
     * @dev Create an instant party with default parameters
     */
    function createDefaultInstantParty(
        address creator
    ) public returns (uint256 partyId) {
        vm.prank(creator);
        partyId = partyStarter.createInstantParty{value: PARTY_ETH_AMOUNT}(
            createDefaultMetadata()
        );
    }

    /**
     * @dev Create a public party with default parameters
     */
    function createDefaultPublicParty(
        address creator
    ) public returns (uint256 partyId) {
        vm.prank(creator);
        partyId = partyStarter.createPublicParty(
            createDefaultMetadata(),
            PARTY_ETH_AMOUNT
        );
    }

    /**
     * @dev Create a private party with default parameters
     */
    function createDefaultPrivateParty(
        address creator
    ) public returns (uint256 partyId) {
        vm.prank(creator);
        partyId = partyStarter.createPrivateParty(
            createDefaultMetadata(),
            PARTY_ETH_AMOUNT,
            creator // Use creator as signer for simplicity
        );
    }

    /**
     * @dev Get party details
     */
    function getPartyDetails(
        uint256 partyId
    ) public view returns (PartyTypes.Party memory) {
        return partyStarter.getParty(partyId);
    }

    /**
     * @dev Check if party is launched
     */
    function isPartyLaunched(uint256 partyId) public view returns (bool) {
        PartyTypes.Party memory party = getPartyDetails(partyId);
        return party.launched;
    }

    /**
     * @dev Get token address for a party
     */
    function getPartyToken(uint256 partyId) public view returns (address) {
        PartyTypes.Party memory party = getPartyDetails(partyId);
        return party.tokenAddress;
    }

    /**
     * @dev Assert party was created correctly
     */
    function assertPartyCreated(
        uint256 partyId,
        PartyTypes.PartyType expectedType,
        address expectedCreator
    ) public {
        PartyTypes.Party memory party = getPartyDetails(partyId);

        assertEq(uint(party.partyType), uint(expectedType), "Wrong party type");
        assertEq(party.creator, expectedCreator, "Wrong creator");
        assertEq(party.id, partyId, "Wrong party ID");
        assertGt(party.createdAt, 0, "Creation timestamp should be set");
    }

    /**
     * @dev Assert party was launched correctly
     */
    function assertPartyLaunched(uint256 partyId) public {
        PartyTypes.Party memory party = getPartyDetails(partyId);

        assertTrue(party.launched, "Party should be launched");
        assertTrue(
            party.tokenAddress != address(0),
            "Token address should be set"
        );
        assertTrue(PoolId.unwrap(party.poolId) != 0, "Pool ID should be set");
        assertGt(
            party.totalLiquidity,
            0,
            "Total liquidity should be greater than 0"
        );
    }

    /**
     * @dev Assert token was created correctly
     */
    function assertTokenCreated(
        address tokenAddress,
        string memory expectedName
    ) public {
        assertTrue(
            tokenAddress != address(0),
            "Token address should not be zero"
        );

        UniswapV4ERC20 token = UniswapV4ERC20(tokenAddress);
        assertEq(token.name(), expectedName, "Wrong token name");
        assertGt(token.totalSupply(), 0, "Token should have supply");
    }

    /**
     * @dev Simulate multiple users creating parties
     */
    function simulateMultipleParties(
        uint256 count,
        PartyTypes.PartyType partyType
    ) public {
        for (uint256 i = 0; i < count; i++) {
            address creator = address(uint160(0x3000 + i));
            vm.deal(creator, INITIAL_ETH_BALANCE);

            if (partyType == PartyTypes.PartyType.INSTANT) {
                createDefaultInstantParty(creator);
            } else if (partyType == PartyTypes.PartyType.PUBLIC) {
                createDefaultPublicParty(creator);
            } else {
                createDefaultPrivateParty(creator);
            }
        }
    }

    /**
     * @dev Generate random token metadata for fuzz testing
     */
    function generateRandomMetadata(
        uint256 seed
    ) public pure returns (PartyTypes.TokenMetadata memory) {
        return
            PartyTypes.TokenMetadata({
                name: string(abi.encodePacked("Token", vm.toString(seed))),
                symbol: string(
                    abi.encodePacked("TKN", vm.toString(seed % 1000))
                ),
                description: "Fuzz test token",
                image: "https://example.com/fuzz.png",
                website: "https://fuzz.example.com",
                twitter: "https://twitter.com/fuzz",
                telegram: "https://t.me/fuzz"
            });
    }

    /**
     * @dev Skip to next block
     */
    function skipBlocks(uint256 blocks) public {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + (blocks * 12)); // Assume 12 second blocks
    }

    /**
     * @dev Print gas usage report
     */
    function printGasReport(string memory operation) public view {
        console.log("=== GAS REPORT ===");
        console.log("Operation:", operation);
        console.log("Gas Used:", gasUsed);
        console.log("==================");
    }

    // ============ Assertion Helpers ============

    /**
     * @dev Assert addresses are different
     */
    function assertNotEq(
        address a,
        address b,
        string memory err
    ) internal pure override {
        assertTrue(a != b, err);
    }

    /**
     * @dev Assert that a value is within a range
     */
    function assertInRange(
        uint256 value,
        uint256 min,
        uint256 max,
        string memory err
    ) internal {
        assertTrue(value >= min && value <= max, err);
    }

    /**
     * @dev Assert contract has expected balance
     */
    function assertContractBalance(
        address contractAddr,
        uint256 expectedBalance
    ) internal {
        assertEq(
            contractAddr.balance,
            expectedBalance,
            "Contract balance mismatch"
        );
    }
}
