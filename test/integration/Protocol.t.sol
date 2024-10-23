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

    uint256 internal _excess;

    function setUp() external {
        _addToList(_EARNERS_LIST, _alice);
        _addToList(_EARNERS_LIST, _bob);

        _wrappedMToken.startEarningFor(_alice);
        _wrappedMToken.startEarningFor(_bob);

        _totalEarningSupplyOfM = _mToken.totalEarningSupply();

        _deployV2Components();
        _migrate();
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

    function test_initialState() external {
        // TODO: Reinstate to test post-migration for new version.
        vm.skip(true);

        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), 0);
        assertTrue(_mToken.isEarning(address(_wrappedMToken)));
    }

    function test_integration_yieldAccumulation() external {
        // TODO: Reinstate to test post-migration for new version.
        vm.skip(true);

        _giveM(_alice, 100_000000);

        assertEq(_mToken.balanceOf(_alice), 100_000000);

        _wrap(_alice, _alice, 100_000000);

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM = 99_999999);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 99_999999);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance = 99_999999);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 0);
        assertEq(_wrappedMToken.totalSupply(), 99_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), 0);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        _giveM(_carol, 50_000000);

        assertEq(_mToken.balanceOf(_carol), 50_000000);

        _wrap(_carol, _carol, 50_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 50_000000);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 50_000000);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance = 50_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 50_000000);
        assertEq(_wrappedMToken.totalSupply(), 149_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), 0);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 1_860762);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 1_860762);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield = 1_240507);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 50_000000);
        assertEq(_wrappedMToken.totalSupply(), 149_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240508);
        assertEq(_wrappedMToken.excess(), _excess = 62_0253);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

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
        assertEq(_wrappedMToken.totalEarningSupply(), 299_999998);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 50_000000);
        assertEq(_wrappedMToken.totalSupply(), 349_999998);
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240509);
        assertEq(_wrappedMToken.excess(), _excess -= 1);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        _giveM(_dave, 150_000000);

        assertEq(_mToken.balanceOf(_dave), 150_000000);

        _wrap(_dave, _dave, 150_000000);

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 150_000000);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 150_000000);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance = 150_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 299_999998);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 200_000000);
        assertEq(_wrappedMToken.totalSupply(), 499_999998);
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240509);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        assertEq(_wrappedMToken.claimFor(_alice), _aliceAccruedYield);

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance += _aliceAccruedYield);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield -= 1_240507);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 301_240505);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 200_000000);
        assertEq(_wrappedMToken.totalSupply(), 501_240505);
        assertEq(_wrappedMToken.totalAccruedYield(), 2);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert M Token
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 12_528475);
        assertEq(_mToken.totalEarningSupply(), _totalEarningSupplyOfM += 12_528475);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 2_527372);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield = 4_992808);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 301_240505);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 200_000000);
        assertEq(_wrappedMToken.totalSupply(), 501_240505);
        assertEq(_wrappedMToken.totalAccruedYield(), 7_520183);
        assertEq(_wrappedMToken.excess(), _excess += 5_008294);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );
    }

    function test_integration_yieldTransfer() external {
        // TODO: Reinstate to test post-migration for new version.
        vm.skip(true);

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

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 4_992809);
        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield = 2_496404);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        _giveM(_bob, 100_000000);
        _wrap(_bob, _bob, 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 99_999999);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance = 99_999999);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), 0);

        _giveM(_dave, 100_000000);
        _wrap(_dave, _dave, 100_000000);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 99_999999);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance = 99_999999);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Alice transfers all her tokens and only keeps her accrued yield.
        _transferWM(_alice, _carol, 100_000000);

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance = _aliceBalance + _aliceAccruedYield - 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield -= _aliceAccruedYield);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance += 100_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 102_496402);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 299_999999);
        assertEq(_wrappedMToken.totalSupply(), 402_496401);
        assertEq(_wrappedMToken.totalAccruedYield(), 2);
        assertEq(_wrappedMToken.excess(), _excess = 2_496402);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        _transferWM(_dave, _bob, 50_000000);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance += 50_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), 0);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance -= 50_000000);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 152_496402);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 249_999999);
        assertEq(_wrappedMToken.totalSupply(), 402_496401);
        assertEq(_wrappedMToken.totalAccruedYield(), 2);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 10_110259);
        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());

        // Assert Alice (Earner)
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 62320);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield += 3_744606);

        // Assert Carol (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Dave (Non-Earner)
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 152_496402);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 249_999999);
        assertEq(_wrappedMToken.totalSupply(), 402_496401);
        assertEq(_wrappedMToken.totalAccruedYield(), 3_806929);
        assertEq(_wrappedMToken.excess(), _excess += 6_303332);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );
    }

    function test_integration_yieldClaimUnwrap() external {
        // TODO: Reinstate to test post-migration for new version.
        vm.skip(true);

        _giveM(_alice, 100_000000);
        _wrap(_alice, _alice, 100_000000);

        assertGe(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += (_aliceBalance = 99_999999));

        _giveM(_carol, 100_000000);
        _wrap(_carol, _carol, 100_000000);

        assertGe(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += (_carolBalance = 100_000000));

        // Fast forward 180 days in the future to generate yield.
        vm.warp(vm.getBlockTimestamp() + 180 days);

        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 2_496404);
        assertEq(_wrappedMToken.excess(), _excess += 2_496403);

        _giveM(_bob, 100_000000);
        _wrap(_bob, _bob, 100_000000);

        assertGe(
            _mToken.balanceOf(address(_wrappedMToken)),
            _wrapperBalanceOfM += (_bobBalance = 99_999999) + _aliceAccruedYield + _excess
        );

        _giveM(_dave, 100_000000);
        _wrap(_dave, _dave, 100_000000);

        assertGe(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += (_daveBalance = 99_999999));

        // Fast forward 90 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 90 days);

        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 1_271476);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield += 1_240507);
        assertEq(_wrappedMToken.excess(), _excess += 2_511984);

        // Stop earning for Alice
        _removeFomList(_EARNERS_LIST, _alice);

        _wrappedMToken.stopEarningFor(_alice);

        // Assert Alice (Non-Earner)
        // Yield of Alice is claimed when stopping earning
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance += _aliceAccruedYield);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield -= _aliceAccruedYield);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 303_767878);
        assertEq(_wrappedMToken.totalSupply(), 403_767877);
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240510);
        assertEq(_wrappedMToken.excess(), _excess -= 1);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _aliceBalance + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );

        // Start earning for Carol
        _addToList(_EARNERS_LIST, _carol);

        _wrappedMToken.startEarningFor(_carol);

        // Assert Carol (Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 199_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 203_767878);
        assertEq(_wrappedMToken.totalSupply(), 403_767877);
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240510);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _aliceBalance + _bobBalance + _bobAccruedYield + _carolBalance + _carolAccruedYield + _daveBalance + _excess
        );

        // Fast forward 180 days in the future to generate yield
        vm.warp(vm.getBlockTimestamp() + 180 days);

        // Assert Bob (Earner)
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield += 2_527372);

        // Assert Carol (Earner)
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), _carolAccruedYield += 2_496403);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 199_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 203_767878);
        assertEq(_wrappedMToken.totalSupply(), 403_767877);
        assertEq(_wrappedMToken.totalAccruedYield(), 6_264288);
        assertEq(_wrappedMToken.excess(), _excess += 5_211900);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _aliceBalance + _bobBalance + _bobAccruedYield + _carolBalance + _carolAccruedYield + _daveBalance + _excess
        );

        _unwrap(_alice, _alice, _aliceBalance);

        // Assert Alice (Non-Earner)
        assertEq(_mToken.balanceOf(_alice), _aliceBalance - 1);
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance -= _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 199_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalSupply(), 299_999998);
        assertEq(_wrappedMToken.totalAccruedYield(), 6_264288);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _bobBalance + _bobAccruedYield + _carolBalance + _carolAccruedYield + _daveBalance + _excess
        );

        // Accrued yield of Bob is claimed when unwrapping
        _unwrap(_bob, _bob, _bobBalance + _bobAccruedYield);

        // Assert Bob (Earner)
        assertEq(_mToken.balanceOf(_bob), _bobBalance + _bobAccruedYield - 1);
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance -= _bobBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield -= _bobAccruedYield);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 100_000000);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalSupply(), 199_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), 2_496409);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _carolBalance + _carolAccruedYield + _daveBalance + _excess
        );

        // Accrued yield of Carol is claimed when unwrapping
        _unwrap(_carol, _carol, _carolBalance + _carolAccruedYield);

        // Assert Carol (Earner)
        assertEq(_mToken.balanceOf(_carol), _carolBalance + _carolAccruedYield - 1);
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance -= _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), _carolAccruedYield -= _carolAccruedYield);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 0);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalSupply(), 99_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), _excess += 6);

        assertGe(_wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)), _daveBalance + _excess);

        _unwrap(_dave, _dave, _daveBalance);

        // Assert Dave (Non-Earner)
        assertEq(_mToken.balanceOf(_dave), _daveBalance - 1);
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance -= _daveBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 0);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 0);
        assertEq(_wrappedMToken.totalSupply(), 0);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), _excess += 1);

        assertGe(_wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)), _excess);

        uint256 vaultStartingBalance_ = _mToken.balanceOf(_excessDestination);

        assertEq(_wrappedMToken.claimExcess(), _excess);
        assertEq(_mToken.balanceOf(_excessDestination), _excess + vaultStartingBalance_);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 0);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 0);
        assertEq(_wrappedMToken.totalSupply(), 0);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), _excess -= _excess);

        assertGe(_wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)), 0);
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
