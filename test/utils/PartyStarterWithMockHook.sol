// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PartyStarterWithHook} from "./PartyStarterWithHook.sol";
import {MockValidHook} from "./MockValidHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PartyVault} from "../../src/vault/PartyVault.sol";
import {EarlySwapLimitHook} from "../../src/hooks/EarlySwapLimitHook.sol";

/**
 * @title PartyStarterWithMockHook
 * @dev Test version of PartyStarter that uses MockValidHook for testing
 */
contract PartyStarterWithMockHook is PartyStarterWithHook {
    constructor(
        IPoolManager _poolManager,
        PartyVault _partyVault,
        address _weth,
        address _platformTreasury,
        EarlySwapLimitHook _swapLimitHook
    )
        PartyStarterWithHook(
            _poolManager,
            _partyVault,
            _weth,
            _platformTreasury,
            _swapLimitHook
        )
    {}
}
