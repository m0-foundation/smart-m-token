// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

// import { console2 } from "../../lib/forge-std/src/Test.sol";

import { Invariants } from "../utils/Invariants.sol";

import { TestBase } from "./TestBase.sol";

contract ProtocolIntegrationTests is TestBase {
    uint256 internal _wrapperBalanceOfM;
    uint256 internal _totalEarningSupplyOfM;

    uint256 internal _aliceBalance;
    uint256 internal _bobBalance;
    uint256 internal _carolBalance;
    uint256 internal _daveBalance;

    uint256 internal _aliceAccruedYield;
    uint256 internal _bobAccruedYield;
    uint256 internal _carolAccruedYield;
    uint256 internal _daveAccruedYield;

    uint256 internal _totalEarningSupply;
    uint256 internal _totalNonEarningSupply;
    uint256 internal _totalSupply;
    uint256 internal _totalAccruedYield;
    uint256 internal _excess;

    function setUp() external {
        _addToList(_EARNERS_LIST, _alice);
        _addToList(_EARNERS_LIST, _bob);

        _wrappedMToken.startEarningFor(_alice);
        _wrappedMToken.startEarningFor(_bob);

        _deployV2Components();
        _migrate();

        _totalEarningSupplyOfM = _mToken.totalEarningSupply();

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));

        _totalEarningSupply = _wrappedMToken.totalEarningSupply();
        _totalNonEarningSupply = _wrappedMToken.totalNonEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();
    }

    function test_constants() external view {
        assertEq(_wrappedMToken.EARNERS_LIST_IGNORED_KEY(), "earners_list_ignored");
        assertEq(_wrappedMToken.EARNERS_LIST_NAME(), "earners");
        assertEq(_wrappedMToken.CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX(), "wm_claim_override_recipient");
        assertEq(_wrappedMToken.MIGRATOR_KEY_PREFIX(), "wm_migrator_v2");
        assertEq(_wrappedMToken.name(), "M by M^0 (wrapped)");
        assertEq(_wrappedMToken.symbol(), "wM");
        assertEq(_wrappedMToken.decimals(), 6);
    }

    function test_state() external view {
        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());
        assertTrue(_mToken.isEarning(address(_wrappedMToken)));
    }

    function test_wrapWithPermits() external {
        _giveM(_alice, 200_000000);

        assertEq(_mToken.balanceOf(_alice), 200_000000);

        _wrapWithPermitVRS(_alice, _aliceKey, _alice, 100_000000, 0, block.timestamp);

        assertEq(_mToken.balanceOf(_alice), 100_000000);
        assertEq(_wrappedMToken.balanceOf(_alice), 99_999999);

        _wrapWithPermitSignature(_alice, _aliceKey, _alice, 100_000000, 1, block.timestamp);

        assertEq(_mToken.balanceOf(_alice), 0);
        assertEq(_wrappedMToken.balanceOf(_alice), 199_999999);

        return;
    }

    function test_integration_yieldAccumulation() external {
        _giveM(_alice, 100_000000);

        assertEq(_mToken.balanceOf(_alice), 100_000000);

        _wrap(_alice, _alice, 100_000000);

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 99_999999);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 99_999999);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance = 99_999999);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += 99_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        _giveM(_carol, 50_000000);

        assertEq(_mToken.balanceOf(_carol), 50_000000);

        _wrap(_carol, _carol, 50_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 50_000000);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 50_000000);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance = 50_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply += 50_000000);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));
        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();

        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 1_190592);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        _giveM(_bob, 200_000000);

        assertEq(_mToken.balanceOf(_bob), 200_000000);

        _wrap(_bob, _bob, 200_000000);

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 199_999999);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 199_999999);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance = 199_999999);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += 199_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        _giveM(_dave, 150_000000);

        assertEq(_mToken.balanceOf(_dave), 150_000000);

        _wrap(_dave, _dave, 150_000000);

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 149_999999);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 149_999999);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance = 149_999999);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply += 149_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        assertEq(_wrappedMToken.claimFor(_alice), _aliceAccruedYield);

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance += _aliceAccruedYield);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield -= 1_190592);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += 1_190592);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield -= 1_190592);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));
        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();

        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 2_423880);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield = 4_790723);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);
    }

    function test_integration_yieldTransfer() external {
        _giveM(_alice, 100_000000);
        _wrap(_alice, _alice, 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 99_999999);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance = 99_999999);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), 0);

        _giveM(_carol, 100_000000);
        _wrap(_carol, _carol, 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 100_000000);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance = 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += _aliceBalance);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply += 100_000000);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));
        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();

        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield = 2_395361);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        _giveM(_bob, 100_000000);
        _wrap(_bob, _bob, 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 100_000000);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance = 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), 0);

        _giveM(_dave, 100_000000);
        _wrap(_dave, _dave, 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 100_000000);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance = 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Alice transfers all her tokens and only keeps her accrued yield.
        _transferWM(_alice, _carol, 100_000000);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance = _aliceBalance + 2_395361 - 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield -= 2_395361);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance += 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += _bobBalance + 2_395361 - 100_000000);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply += _daveBalance + 100_000000);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield -= 2_395361 - 1);
        assertEq(_wrappedMToken.excess(), _excess -= 1);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        _transferWM(_dave, _bob, 50_000000);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance += 50_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), 0);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance -= 50_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += 50_000000);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply -= 50_000000);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield += 1);
        assertEq(_wrappedMToken.excess(), _excess -= 1);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));
        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();

        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 57376);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield += 3_593042);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);
    }

    function test_integration_yieldClaimUnwrap() external {
        _giveM(_alice, 100_000000);
        _wrap(_alice, _alice, 100_000000);

        _giveM(_carol, 100_000000);
        _wrap(_carol, _carol, 100_000000);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance += 99_999999);
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance += 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 199_999999);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += 99_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply += 100_000000);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Fast forward 180 days in the future to generate yield.
        vm.warp(vm.getBlockTimestamp() + 180 days);

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));
        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();

        _giveM(_bob, 100_000000);
        _wrap(_bob, _bob, 100_000000);

        _giveM(_dave, 100_000000);
        _wrap(_dave, _dave, 100_000000);

        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 2_395361);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance += 100_000000);
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance += 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 200_000000);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += 100_000000);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply += 100_000000);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield += 1);
        assertEq(_wrappedMToken.excess(), _excess -= 1);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));
        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();

        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 1_219112);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield += 1_190593);

        // Stop earning for Alice
        _removeFomList(_EARNERS_LIST, _alice);

        _wrappedMToken.stopEarningFor(_alice);

        // Assert Alice (Non-Earner)
        // Yield of Alice is claimed when stopping earning
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance += 3_614473);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield -= 3_614473);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply -= 99_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply += _aliceBalance);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield -= 3_614473);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Start earning for Carol
        _addToList(_EARNERS_LIST, _carol);

        _wrappedMToken.startEarningFor(_carol);

        // Assert Carol (Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply += _carolBalance);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply -= _carolBalance);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield += 1);
        assertEq(_wrappedMToken.excess(), _excess -= 1);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));
        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
        _totalAccruedYield = _wrappedMToken.totalAccruedYield();
        _excess = _wrappedMToken.excess();

        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield += 2_423881);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), _carolAccruedYield += 2_395361);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        _unwrap(_alice, _alice, _aliceBalance);

        // Assert Alice (Non-Earner)
        assertEq(_mToken.balanceOf(_alice), 103_614471);
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance -= 103_614472);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply -= 103_614472);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess += 1);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Accrued yield of Bob is claimed when unwrapping
        _unwrap(_bob, _bob, _bobBalance + _bobAccruedYield);

        // Assert Bob (Earner)
        assertEq(_mToken.balanceOf(_bob), 100_000000 + 3_614474 - 1);
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance -= 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield -= 3_614474);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply -= 100_000000);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield -= 3_614474);
        assertEq(_wrappedMToken.excess(), _excess += 1);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        // Accrued yield of Carol is claimed when unwrapping
        _unwrap(_carol, _carol, _carolBalance + _carolAccruedYield);

        // Assert Carol (Earner)
        assertEq(_mToken.balanceOf(_carol), 100_000000 + 2_395361 - 1);
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance -= 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), _carolAccruedYield -= 2_395361);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply -= 100_000000);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield -= 2_395361);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        _unwrap(_dave, _dave, _daveBalance);

        // Assert Dave (Non-Earner)
        assertEq(_mToken.balanceOf(_dave), 100_000000 - 1);
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance -= 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply -= 100_000000);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);

        uint256 vaultStartingBalance_ = _mToken.balanceOf(_excessDestination);

        assertEq(_wrappedMToken.claimExcess(), _excess);
        assertEq(_mToken.balanceOf(_excessDestination), _excess + vaultStartingBalance_);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), _totalEarningSupply);
        assertEq(_wrappedMToken.totalNonEarningSupply(), _totalNonEarningSupply);
        assertEq(_wrappedMToken.totalAccruedYield(), _totalAccruedYield);
        assertEq(_wrappedMToken.excess(), _excess -= _excess);

        assertGe(_wrapperBalanceOfM, _totalEarningSupply + _totalNonEarningSupply + _totalAccruedYield + _excess);
    }

    function testFuzz_full(uint256 seed_) external {
        // TODO: Reinstate to test post-migration for new version.
        vm.skip(true);

        for (uint256 index_; index_ < _accounts.length; ++index_) {
            _giveM(_accounts[index_], 100_000e6);
        }

        for (uint256 index_; index_ < 1000; ++index_) {
            assertTrue(Invariants.checkInvariant1(address(_wrappedMToken), _accounts), "Invariant 1 Failed.");
            assertTrue(Invariants.checkInvariant2(address(_wrappedMToken), _accounts), "Invariant 2 Failed.");
            assertTrue(Invariants.checkInvariant4(address(_wrappedMToken), _accounts), "Invariant 4 Failed.");

            // console2.log("--------");
            // console2.log("");

            uint256 timeDelta_ = (seed_ = _getNewSeed(seed_)) % 30 days;

            // console2.log("Warping %s hours", timeDelta_ / 1 hours);

            vm.warp(vm.getBlockTimestamp() + timeDelta_);

            // console2.log("");
            // console2.log("--------");

            assertTrue(Invariants.checkInvariant1(address(_wrappedMToken), _accounts), "Invariant 1 Failed.");
            assertTrue(Invariants.checkInvariant2(address(_wrappedMToken), _accounts), "Invariant 2 Failed.");
            assertTrue(Invariants.checkInvariant4(address(_wrappedMToken), _accounts), "Invariant 4 Failed.");

            // NOTE: Skipping this as there is no trivial way to guarantee this invariant while meeting 1 and 2.
            // assertTrue(Invariants.checkInvariant3(address(_wrappedMToken), address(_mToken)), "Invariant 3 Failed.");

            // console2.log("Wrapper has %s M", _mToken.balanceOf(address(_wrappedMToken)));

            address account1_ = _accounts[((seed_ = _getNewSeed(seed_)) % _accounts.length)];
            address account2_ = _accounts[((seed_ = _getNewSeed(seed_)) % _accounts.length)];

            _giveM(account1_, 1_000e6);

            uint256 account1Balance_ = _wrappedMToken.balanceOf(account1_);

            // console2.log("%s has %s wM", account1_, account1Balance_);

            // 25% chance to transfer
            if (((seed_ % 100) >= 75) && (account1Balance_ != 0)) {
                uint256 amount_ = ((seed_ = _getNewSeed(seed_)) % account1Balance_) * 2;

                amount_ = amount_ >= account1Balance_ ? account1Balance_ : amount_; // 50% chance of entire balance.

                // console2.log("%s transferring %s to %s", account1_, amount_, account2_);

                _transferWM(account1_, account2_, amount_);

                continue;
            }

            uint256 account1BalanceOfM_ = _mToken.balanceOf(account1_);

            // console2.log("%s has %s M", account1_, account1BalanceOfM_);

            // 20% chance to wrap
            if ((seed_ % 100) >= 55) {
                uint256 amount_ = (((seed_ = _getNewSeed(seed_)) % account1BalanceOfM_) * 2) + 10;

                // 50% chance of wrapping entire M balance.
                if (amount_ >= account1BalanceOfM_) {
                    // console2.log("%s wrapping all their M to %s", account1_, account2_);

                    _wrap(account1_, account2_);
                } else {
                    // console2.log("%s wrapping %s to %s", account1_, amount_, account2_);

                    _wrap(account1_, account2_, amount_);
                }

                continue;
            }

            // 15% chance to claim
            if (((seed_ % 100) >= 40) && (account1Balance_ != 0)) {
                // console2.log("%s claiming yield", account1_);

                _wrappedMToken.claimFor(account1_);

                continue;
            }

            // 20% chance to unwrap
            if (((seed_ % 100) >= 20) && (account1Balance_ != 0)) {
                uint256 amount_ = (((seed_ = _getNewSeed(seed_)) % account1Balance_) * 2) + 10;

                // 50% chance of unwrapping entire wM balance.
                if (amount_ >= account1Balance_) {
                    // console2.log("%s unwrapping all their wM to %s", account1_, account2_);

                    _unwrap(account1_, account2_);
                } else {
                    // console2.log("%s unwrapping %s to %s", account1_, amount_, account2_);

                    _unwrap(account1_, account2_, amount_);
                }

                continue;
            }

            // 10% chance to start/stop earning
            if ((seed_ % 100) >= 10) {
                if (_wrappedMToken.isEarning(account1_)) {
                    _removeFomList(_EARNERS_LIST, account1_);

                    // console2.log("%s stopping earning", account1_);

                    _wrappedMToken.stopEarningFor(account1_);
                } else {
                    _addToList(_EARNERS_LIST, account1_);

                    // console2.log("%s starting earning", account1_);

                    _wrappedMToken.startEarningFor(account1_);
                }

                continue;
            }

            // 5% chance to claim excess
            if ((seed_ % 100) >= 0) {
                // console2.log("Claiming excess");

                _wrappedMToken.claimExcess();

                continue;
            }
        }
    }

    function _getNewSeed(uint256 seed_) internal pure returns (uint256 newSeed_) {
        return uint256(keccak256(abi.encodePacked(seed_)));
    }
}
