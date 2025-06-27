// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TestBase} from "../utils/TestBase.sol";
import {PartyTypes} from "../../src/types/PartyTypes.sol";
import {PartyVenue} from "../../src/venue/PartyVenue.sol";
import {UniswapV4ERC20} from "../../src/tokens/UniswapV4ERC20.sol";
import {PartyStarter} from "../../src/PartyStarter.sol";
import {IPartyStarter} from "../../src/interfaces/IPartyStarter.sol";
import {PartyErrors} from "../../src/types/PartyErrors.sol";

contract PartyFuzzTest is TestBase {
    // ============ Instant Party Fuzz Tests ============

    function testFuzz_InstantParty_RandomInputs(
        address creator,
        uint256 ethAmount,
        uint256 nameSeed,
        uint256 symbolSeed
    ) public {
        // Bound inputs to valid ranges
        vm.assume(creator != address(0));
        vm.assume(creator.code.length == 0); // EOA only
        vm.assume(ethAmount >= 0.001 ether && ethAmount <= 1000 ether);

        // Give creator enough balance
        vm.deal(creator, ethAmount + 1 ether);

        PartyTypes.TokenMetadata memory metadata = generateRandomMetadata(
            nameSeed
        );

        // Create party
        vm.prank(creator);
        uint256 partyId = partyStarter.createInstantParty{value: ethAmount}(
            metadata
        );

        // Verify party was created correctly
        assertPartyCreated(partyId, PartyTypes.PartyType.INSTANT, creator);
        assertPartyLaunched(partyId);

        // Verify token distribution
        PartyTypes.Party memory party = getPartyDetails(partyId);
        UniswapV4ERC20 token = UniswapV4ERC20(party.tokenAddress);

        // Check token balances are correct
        assertEq(token.balanceOf(creator), PartyTypes.DEFAULT_CREATOR_TOKENS);
        assertEq(
            token.balanceOf(address(partyVault)),
            PartyTypes.DEFAULT_VAULT_TOKENS
        );

        // Check fee distribution
        uint256 expectedPlatformFee = (ethAmount *
            PartyTypes.PLATFORM_FEE_BPS) / 10000;
        uint256 expectedLiquidity = ethAmount - expectedPlatformFee;
        assertEq(party.totalLiquidity, expectedLiquidity);
    }

    function testFuzz_InstantParty_MultipleCreators(
        address[10] memory creators,
        uint256[10] memory ethAmounts
    ) public {
        uint256 validParties = 0;

        for (uint256 i = 0; i < creators.length; i++) {
            // Skip invalid inputs
            if (creators[i] == address(0) || creators[i].code.length > 0)
                continue;
            if (ethAmounts[i] < 0.001 ether || ethAmounts[i] > 100 ether)
                continue;

            vm.deal(creators[i], ethAmounts[i] + 1 ether);

            PartyTypes.TokenMetadata memory metadata = generateRandomMetadata(
                i
            );

            vm.prank(creators[i]);
            uint256 partyId = partyStarter.createInstantParty{
                value: ethAmounts[i]
            }(metadata);

            // Verify each party
            assertPartyCreated(
                partyId,
                PartyTypes.PartyType.INSTANT,
                creators[i]
            );
            assertPartyLaunched(partyId);

            validParties++;
        }

        // Verify party counter
        assertEq(partyStarter.partyCounter(), validParties);
    }

    // ============ Public Party Fuzz Tests ============

    function testFuzz_PublicParty_RandomTargets(
        address creator,
        uint256 targetLiquidity,
        uint256 contributionAmount
    ) public {
        // Bound inputs
        vm.assume(creator != address(0));
        vm.assume(creator.code.length == 0);
        vm.assume(
            targetLiquidity >= 0.01 ether && targetLiquidity <= 1000 ether
        );
        vm.assume(
            contributionAmount > 0 && contributionAmount <= targetLiquidity
        );

        vm.deal(creator, 1 ether);
        vm.deal(BOB, contributionAmount + 1 ether);

        PartyTypes.TokenMetadata memory metadata = generateRandomMetadata(
            uint256(uint160(creator))
        );

        // Create public party
        vm.prank(creator);
        uint256 partyId = partyStarter.createPublicParty(
            metadata,
            targetLiquidity
        );

        // Verify party creation
        assertPartyCreated(partyId, PartyTypes.PartyType.PUBLIC, creator);
        assertFalse(isPartyLaunched(partyId));

        // Get venue and contribute
        PartyTypes.Party memory party = getPartyDetails(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        vm.prank(BOB);
        venue.contribute{value: contributionAmount}();

        // Check contribution
        assertEq(venue.getContribution(BOB), contributionAmount);

        // If contribution meets target, should launch
        if (contributionAmount >= targetLiquidity) {
            assertTrue(isPartyLaunched(partyId));
        } else {
            assertFalse(isPartyLaunched(partyId));
        }
    }

    function testFuzz_PublicParty_MultipleContributors(
        uint256 targetLiquidity,
        uint256[5] memory contributions
    ) public {
        // Bound inputs
        vm.assume(targetLiquidity >= 0.1 ether && targetLiquidity <= 100 ether);

        // Create public party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            generateRandomMetadata(1),
            targetLiquidity
        );

        PartyTypes.Party memory party = getPartyDetails(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        uint256 totalContributed = 0;
        address[5] memory contributors = [
            BOB,
            CHARLIE,
            address(0x5001),
            address(0x5002),
            address(0x5003)
        ];

        for (uint256 i = 0; i < contributions.length; i++) {
            // Bound contribution
            if (contributions[i] == 0 || contributions[i] > 50 ether) continue;
            if (totalContributed + contributions[i] > targetLiquidity * 2)
                continue; // Prevent excessive contributions

            vm.deal(contributors[i], contributions[i] + 1 ether);

            bool shouldLaunch = totalContributed + contributions[i] >=
                targetLiquidity;

            vm.prank(contributors[i]);
            venue.contribute{value: contributions[i]}();

            totalContributed += contributions[i];

            // Check if party launched when target reached
            if (shouldLaunch) {
                assertTrue(isPartyLaunched(partyId));
                break; // Stop contributing after launch
            }
        }
    }

    // ============ Private Party Fuzz Tests ============

    function testFuzz_PrivateParty_SignatureAccess(
        address[3] memory contributors,
        uint256[3] memory contributions
    ) public {
        // Create private party with signature-based authorization
        address signerAddress = ALICE; // Use ALICE as the signer
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPrivateParty(
            generateRandomMetadata(2),
            10 ether,
            signerAddress
        );

        PartyTypes.Party memory party = getPartyDetails(partyId);
        PartyVenue venue = PartyVenue(payable(party.venueAddress));

        // Test signature-based contributions
        for (uint256 i = 0; i < contributors.length; i++) {
            if (contributors[i] == address(0) || contributions[i] == 0)
                continue;
            if (contributions[i] > 10 ether) continue;

            vm.deal(contributors[i], contributions[i] + 1 ether);

            // Try to contribute without signature (should fail for private parties)
            vm.prank(contributors[i]);
            vm.expectRevert("Private parties require signature authorization");
            venue.contribute{value: contributions[i]}();

            // Test with valid signature
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(
                        abi.encodePacked(
                            partyId,
                            contributors[i],
                            contributions[i] * 2, // Max amount higher than contribution
                            block.timestamp + 1 hours
                        )
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash); // Using ALICE's key
            bytes memory signature = abi.encodePacked(r, s, v);

            // Should work with valid signature
            vm.prank(contributors[i]);
            venue.contributeWithSignature{value: contributions[i]}(
                signature,
                contributions[i] * 2,
                block.timestamp + 1 hours
            );

            assertEq(venue.getContribution(contributors[i]), contributions[i]);
        }
    }

    // ============ Fee Claiming Fuzz Tests ============

    function testFuzz_FeeClaiming_RandomAmounts(
        uint256 partyEthAmount,
        uint256 feeAmount
    ) public {
        // Bound inputs
        vm.assume(partyEthAmount >= 0.1 ether && partyEthAmount <= 100 ether);
        vm.assume(feeAmount <= 50 ether);

        vm.deal(ALICE, partyEthAmount + 1 ether);

        // Create instant party
        vm.prank(ALICE);
        uint256 partyId = partyStarter.createInstantParty{
            value: partyEthAmount
        }(generateRandomMetadata(3));

        // Simulate fees accumulated
        vm.deal(address(partyStarter), feeAmount);

        uint256 aliceBalanceBefore = ALICE.balance;

        // Claim fees
        vm.prank(ALICE);
        partyStarter.claimFees(partyId);

        uint256 aliceBalanceAfter = ALICE.balance;

        if (feeAmount > 0) {
            // Should receive some fees
            assertGt(aliceBalanceAfter, aliceBalanceBefore);

            // Should receive correct dev share
            uint256 expectedDevAmount = (feeAmount * PartyTypes.DEV_FEE_SHARE) /
                100;
            assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedDevAmount);
        }

        // Cannot claim again
        vm.prank(ALICE);
        vm.expectRevert("Fees already claimed or not available");
        partyStarter.claimFees(partyId);
    }

    // ============ Gas Limit Fuzz Tests ============

    function testFuzz_GasEfficiency_InstantParty(uint256 ethAmount) public {
        // Bound to reasonable amounts
        vm.assume(ethAmount >= 0.01 ether && ethAmount <= 10 ether);

        vm.deal(ALICE, ethAmount + 1 ether);

        startMeasureGas();

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createInstantParty{value: ethAmount}(
            generateRandomMetadata(4)
        );

        uint256 gasUsed = endMeasureGas();

        // Verify party was created
        assertPartyLaunched(partyId);

        // Gas should be reasonable regardless of ETH amount
        assertTrue(gasUsed < 2000000); // 2M gas limit
    }

    function testFuzz_GasEfficiency_PublicParty(
        uint256 targetLiquidity,
        uint8 whitelistSize
    ) public {
        // Bound inputs
        vm.assume(
            targetLiquidity >= 0.01 ether && targetLiquidity <= 100 ether
        );
        vm.assume(whitelistSize <= 20); // Reasonable whitelist size

        startMeasureGas();

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            generateRandomMetadata(5),
            targetLiquidity
        );

        uint256 gasUsed = endMeasureGas();

        // Verify party was created
        assertPartyCreated(partyId, PartyTypes.PartyType.PUBLIC, ALICE);

        // Gas should be reasonable
        assertTrue(gasUsed < 1500000); // 1.5M gas limit
    }

    // ============ Edge Case Fuzz Tests ============

    function testFuzz_EdgeCases_MaxValues(uint256 seed) public {
        // Test with maximum reasonable values
        uint256 maxEth = 100 ether;
        vm.deal(ALICE, maxEth + 1 ether);

        PartyTypes.TokenMetadata memory metadata = generateRandomMetadata(seed);

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createInstantParty{value: maxEth}(
            metadata
        );

        // Should still work with max values
        assertPartyCreated(partyId, PartyTypes.PartyType.INSTANT, ALICE);
        assertPartyLaunched(partyId);

        // Token balances should still be correct
        PartyTypes.Party memory party = getPartyDetails(partyId);
        UniswapV4ERC20 token = UniswapV4ERC20(party.tokenAddress);
        assertEq(token.balanceOf(ALICE), PartyTypes.DEFAULT_CREATOR_TOKENS);
    }

    function testFuzz_EdgeCases_MinValues(uint256 seed) public {
        // Test with minimum reasonable values
        uint256 minEth = 0.001 ether;
        vm.deal(ALICE, minEth + 1 ether);

        PartyTypes.TokenMetadata memory metadata = generateRandomMetadata(seed);

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createInstantParty{value: minEth}(
            metadata
        );

        // Should still work with min values
        assertPartyCreated(partyId, PartyTypes.PartyType.INSTANT, ALICE);
        assertPartyLaunched(partyId);

        // Fee calculation should work correctly even with small amounts
        PartyTypes.Party memory party = getPartyDetails(partyId);
        uint256 expectedPlatformFee = (minEth * PartyTypes.PLATFORM_FEE_BPS) /
            10000;
        uint256 expectedLiquidity = minEth - expectedPlatformFee;
        assertEq(party.totalLiquidity, expectedLiquidity);
    }

    // ============ Security Fuzz Tests ============

    function testFuzz_Security_ReentrancyProtection(uint256 ethAmount) public {
        // Bound input
        vm.assume(ethAmount >= 0.1 ether && ethAmount <= 10 ether);

        // Deploy a malicious contract that tries to re-enter
        MaliciousReentrancy malicious = new MaliciousReentrancy(
            IPartyStarter(address(partyStarter))
        );
        vm.deal(address(malicious), ethAmount + 1 ether);

        // Try to create party with malicious contract
        // Should either succeed normally or revert, but not cause reentrancy issues
        try malicious.attemptReentrancy{value: ethAmount}() {
            // If successful, verify normal behavior
            uint256 partyId = partyStarter.partyCounter();
            if (partyId > 0) {
                // Verify the party was created normally
                PartyTypes.Party memory party = getPartyDetails(partyId);
                assertTrue(party.launched);
            }
        } catch {
            // Revert is acceptable for reentrancy protection
        }
    }

    function testFuzz_Security_AccessControl(
        address randomUser,
        uint256 partyId
    ) public {
        // Bound inputs
        vm.assume(randomUser != address(0));
        vm.assume(randomUser != ALICE);
        vm.assume(randomUser.code.length == 0);
        vm.assume(partyId > 0 && partyId <= 1000);

        // Create a party first
        uint256 realPartyId = createDefaultInstantParty(ALICE);

        vm.deal(randomUser, 10 ether);

        // Random user should not be able to claim fees for Alice's party
        vm.prank(randomUser);
        vm.expectRevert("Only creator can claim fees");
        partyStarter.claimFees(realPartyId);

        // Random user should not be able to call launchFromVenue directly
        vm.prank(randomUser);
        vm.expectRevert("Only venue can trigger launch");
        partyStarter.launchFromVenue{value: 1 ether}(realPartyId);
    }

    // ============ State Consistency Fuzz Tests ============

    function testFuzz_StateConsistency_MultipleOperations(
        uint8 operationCount,
        uint256 seed
    ) public {
        // Bound operation count
        vm.assume(operationCount >= 1 && operationCount <= 20);

        uint256 initialPartyCount = partyStarter.partyCounter();
        uint256 initialTreasuryBalance = TREASURY.balance;
        uint256 initialVaultTokenCount = partyVault.getTokenCount();

        uint256 partiesCreated = 0;

        for (uint256 i = 0; i < operationCount; i++) {
            address creator = address(uint160(0x6000 + i));
            vm.deal(creator, 10 ether);

            uint256 operation = (seed + i) % 3; // 0=instant, 1=public, 2=private

            if (operation == 0) {
                // Create instant party
                vm.prank(creator);
                partyStarter.createInstantParty{value: 1 ether}(
                    generateRandomMetadata(seed + i)
                );
                partiesCreated++;
            } else if (operation == 1) {
                // Create public party
                vm.prank(creator);
                partyStarter.createPublicParty(
                    generateRandomMetadata(seed + i),
                    2 ether
                );
                partiesCreated++;
            } else {
                // Create private party
                address signerAddress = creator; // Use creator as the signer
                vm.prank(creator);
                uint256 partyId = partyStarter.createPrivateParty(
                    generateRandomMetadata(seed + i),
                    2 ether,
                    signerAddress
                );
                partiesCreated++;
            }
        }

        // Verify final state consistency
        assertEq(
            partyStarter.partyCounter(),
            initialPartyCount + partiesCreated
        );
        assertGt(TREASURY.balance, initialTreasuryBalance); // Should have received some fees
        assertEq(
            partyVault.getTokenCount(),
            initialVaultTokenCount + partiesCreated
        ); // Should have tokens from instant parties
    }

    function testFuzz_CreateInstantParty(
        uint256 ethAmount,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(ethAmount > 0 && ethAmount < 1000 ether);
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);

        address creator = address(uint160(0x8000 + (ethAmount % 1000)));
        vm.deal(creator, ethAmount + 1 ether);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: symbol,
            description: "Fuzz test token",
            image: "https://example.com/fuzz.png",
            website: "https://fuzz.com",
            twitter: "https://twitter.com/fuzz",
            telegram: "https://t.me/fuzz"
        });

        vm.prank(creator);
        uint256 partyId = partyStarter.createInstantParty{value: ethAmount}(
            metadata
        );

        assertEq(partyId, partyStarter.partyCounter());

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(party.creator, creator);
        assertTrue(party.launched);
        assertEq(uint(party.partyType), uint(PartyTypes.PartyType.INSTANT));
        assertTrue(party.tokenAddress != address(0));
    }

    function testFuzz_CreateInstantParty_ZeroValue_Reverts(
        string memory name,
        string memory symbol
    ) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: symbol,
            description: "Test token",
            image: "https://example.com/test.png",
            website: "https://test.com",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_AMOUNT
            )
        );
        partyStarter.createInstantParty{value: 0}(metadata);
    }

    function testFuzz_CreatePublicParty(
        uint256 targetLiquidity,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(targetLiquidity > 0 && targetLiquidity < 1000 ether);
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: symbol,
            description: "Fuzz test token",
            image: "https://example.com/fuzz.png",
            website: "https://fuzz.com",
            twitter: "https://twitter.com/fuzz",
            telegram: "https://t.me/fuzz"
        });

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPublicParty(
            metadata,
            targetLiquidity
        );

        assertEq(partyId, partyStarter.partyCounter());

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(party.creator, ALICE);
        assertFalse(party.launched);
        assertEq(uint(party.partyType), uint(PartyTypes.PartyType.PUBLIC));
        assertTrue(party.venueAddress != address(0));
    }

    function testFuzz_CreatePublicParty_ZeroTarget_Reverts(
        string memory name,
        string memory symbol
    ) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: symbol,
            description: "Test token",
            image: "https://example.com/test.png",
            website: "https://test.com",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_TARGET_LIQUIDITY
            )
        );
        partyStarter.createPublicParty(metadata, 0);
    }

    function testFuzz_CreatePrivateParty(
        uint256 targetLiquidity,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(targetLiquidity > 0 && targetLiquidity < 1000 ether);
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: symbol,
            description: "Fuzz test token",
            image: "https://example.com/fuzz.png",
            website: "https://fuzz.com",
            twitter: "https://twitter.com/fuzz",
            telegram: "https://t.me/fuzz"
        });

        vm.prank(ALICE);
        uint256 partyId = partyStarter.createPrivateParty(
            metadata,
            targetLiquidity,
            ALICE
        );

        assertEq(partyId, partyStarter.partyCounter());

        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(party.creator, ALICE);
        assertFalse(party.launched);
        assertEq(uint(party.partyType), uint(PartyTypes.PartyType.PRIVATE));
        assertTrue(party.venueAddress != address(0));
    }

    function testFuzz_CreatePrivateParty_ZeroSigner_Reverts(
        uint256 targetLiquidity,
        string memory name,
        string memory symbol
    ) public {
        vm.assume(targetLiquidity > 0 && targetLiquidity < 1000 ether);
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: symbol,
            description: "Test token",
            image: "https://example.com/test.png",
            website: "https://test.com",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ZERO_SIGNER_ADDRESS
            )
        );
        partyStarter.createPrivateParty(metadata, targetLiquidity, address(0));
    }

    function testFuzz_TokenMetadata_InvalidName_Reverts(
        uint256 ethAmount,
        string memory symbol
    ) public {
        vm.assume(ethAmount > 0 && ethAmount < 1000 ether);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: "", // Empty name should revert
            symbol: symbol,
            description: "Test token",
            image: "https://example.com/test.png",
            website: "https://test.com",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

        vm.deal(ALICE, ethAmount + 1 ether);
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.EMPTY_TOKEN_NAME
            )
        );
        partyStarter.createInstantParty{value: ethAmount}(metadata);
    }

    function testFuzz_TokenMetadata_InvalidSymbol_Reverts(
        uint256 ethAmount,
        string memory name
    ) public {
        vm.assume(ethAmount > 0 && ethAmount < 1000 ether);
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: "", // Empty symbol should revert
            description: "Test token",
            image: "https://example.com/test.png",
            website: "https://test.com",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

        vm.deal(ALICE, ethAmount + 1 ether);
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.EMPTY_TOKEN_SYMBOL
            )
        );
        partyStarter.createInstantParty{value: ethAmount}(metadata);
    }

    function testFuzz_TokenMetadata_LongSymbol_Reverts(
        uint256 ethAmount,
        string memory name
    ) public {
        vm.assume(ethAmount > 0 && ethAmount < 1000 ether);
        vm.assume(bytes(name).length > 0 && bytes(name).length < 32);

        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: name,
            symbol: "VERYLONGSYMBOL", // Too long symbol should revert
            description: "Test token",
            image: "https://example.com/test.png",
            website: "https://test.com",
            twitter: "https://twitter.com/test",
            telegram: "https://t.me/test"
        });

        vm.deal(ALICE, ethAmount + 1 ether);
        vm.prank(ALICE);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.SYMBOL_TOO_LONG
            )
        );
        partyStarter.createInstantParty{value: ethAmount}(metadata);
    }

    function testFuzz_ClaimFees_NonCreator_Reverts(
        uint256 partyId,
        address nonCreator
    ) public {
        vm.assume(partyId > 0 && partyId <= 1000);
        vm.assume(nonCreator != address(0) && nonCreator != ALICE);

        // Create a party first
        uint256 actualPartyId = createDefaultInstantParty(ALICE);

        // Use the actual party ID
        vm.prank(nonCreator);
        vm.expectRevert(
            abi.encodeWithSelector(
                PartyErrors.PartyError.selector,
                PartyErrors.ErrorCode.ONLY_CREATOR_CAN_CLAIM
            )
        );
        partyStarter.claimFees(actualPartyId);
    }

    function testFuzz_MultiplePartiesCreation(uint8 partyCount) public {
        vm.assume(partyCount > 0 && partyCount <= 20); // Reasonable limit for fuzz test

        uint256 initialCounter = partyStarter.partyCounter();

        for (uint256 i = 0; i < partyCount; i++) {
            address creator = address(uint160(0x9000 + i));
            vm.deal(creator, 2 ether);

            vm.prank(creator);
            uint256 partyId = partyStarter.createInstantParty{value: 1 ether}(
                generateRandomMetadata(i)
            );

            // Verify each party
            assertEq(partyId, initialCounter + i + 1);

            PartyTypes.Party memory party = partyStarter.getParty(partyId);
            assertEq(party.creator, creator);
            assertTrue(party.launched);
            assertTrue(party.tokenAddress != address(0));
        }

        assertEq(partyStarter.partyCounter(), initialCounter + partyCount);
    }

    function testFuzz_FeeCalculation(uint256 ethAmount) public {
        vm.assume(ethAmount > 1000 && ethAmount < 100 ether);

        address creator = address(uint160(0x9999));
        vm.deal(creator, ethAmount + 1 ether);

        uint256 treasuryBalanceBefore = TREASURY.balance;

        vm.prank(creator);
        uint256 partyId = partyStarter.createInstantParty{value: ethAmount}(
            createDefaultMetadata()
        );

        // Calculate expected fees
        uint256 expectedPlatformFee = (ethAmount *
            PartyTypes.PLATFORM_FEE_BPS) / 10000;
        uint256 expectedLiquidity = ethAmount - expectedPlatformFee;

        // Verify fee collection
        uint256 actualFeeCollected = TREASURY.balance - treasuryBalanceBefore;
        assertEq(
            actualFeeCollected,
            expectedPlatformFee,
            "Platform fee mismatch"
        );

        // Verify liquidity calculation
        PartyTypes.Party memory party = partyStarter.getParty(partyId);
        assertEq(
            party.totalLiquidity,
            expectedLiquidity,
            "Liquidity calculation mismatch"
        );
    }
}

// ============ Helper Contracts ============

contract MaliciousReentrancy {
    IPartyStarter immutable partyStarter;
    bool entered = false;

    constructor(IPartyStarter _partyStarter) {
        partyStarter = _partyStarter;
    }

    function attemptReentrancy() external payable {
        PartyTypes.TokenMetadata memory metadata = PartyTypes.TokenMetadata({
            name: "Malicious Token",
            symbol: "MAL",
            description: "Reentrancy test",
            image: "",
            website: "",
            twitter: "",
            telegram: ""
        });

        partyStarter.createInstantParty{value: msg.value}(metadata);
    }

    // Try to re-enter when receiving ETH
    receive() external payable {
        if (!entered && address(this).balance > 0) {
            entered = true;
            // Try to create another party (should fail due to reentrancy protection)
            PartyTypes.TokenMetadata memory metadata = PartyTypes
                .TokenMetadata({
                    name: "Reentrancy Token",
                    symbol: "REEN",
                    description: "Reentrancy attempt",
                    image: "",
                    website: "",
                    twitter: "",
                    telegram: ""
                });

            try partyStarter.createInstantParty{value: 0.1 ether}(metadata) {
                // Should not reach here
            } catch {
                // Expected to fail
            }
        }
    }
}
