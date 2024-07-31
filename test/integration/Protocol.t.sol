// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

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

    function setUp() public override {
        super.setUp();

        _addToList(_EARNERS_LIST, address(_wrappedMToken));
        _addToList(_EARNERS_LIST, _alice);
        _addToList(_EARNERS_LIST, _bob);

        _wrappedMToken.enableEarning();

        _wrappedMToken.startEarningFor(_alice);
        _wrappedMToken.startEarningFor(_bob);

        _totalEarningSupplyOfM = _mToken.totalEarningSupply();
    }

    function test_initialState() external view {
        assertEq(_mToken.currentIndex(), _wrappedMToken.currentIndex());
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), 0);
        assertTrue(_mToken.isEarning(address(_wrappedMToken)));
    }

    function test_integration_yieldAccumulation() external {
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
        assertEq(_wrappedMToken.excess(), _excess = 62_0254);

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
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240508);
        assertEq(_wrappedMToken.excess(), _excess);

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
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240508);
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
        assertEq(_wrappedMToken.totalAccruedYield(), 1);
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
        assertEq(_wrappedMToken.totalAccruedYield(), 7_520182);
        assertEq(_wrappedMToken.excess(), _excess += 5_008294);

        assertGe(
            _wrapperBalanceOfM + 1, // TODO: Fix
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );
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
        assertEq(_wrappedMToken.totalAccruedYield(), 1);
        assertEq(_wrappedMToken.excess(), _excess = 2_496404);

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
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), _excess += 1);

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
        assertEq(_wrappedMToken.totalAccruedYield(), 3_806927);
        assertEq(_wrappedMToken.excess(), _excess += 6_303332);

        assertGe(
            _wrapperBalanceOfM,
            _aliceBalance + _aliceAccruedYield + _bobBalance + _bobAccruedYield + _carolBalance + _daveBalance + _excess
        );
    }

    function test_integration_yieldClaimUnwrap() external {
        _giveM(_alice, 100_000000);
        _wrap(_alice, _alice, 100_000000);

        assertGe(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += (_aliceBalance = 99_999999));

        _giveM(_carol, 100_000000);
        _wrap(_carol, _carol, 100_000000);

        assertGe(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += (_carolBalance = 100_000000));

        // Fast forward 180 days in the future to generate yield.
        vm.warp(vm.getBlockTimestamp() + 180 days);

        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield += 2_496404);
        assertEq(_wrappedMToken.excess(), _excess += 2_496404);

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
        assertEq(_wrappedMToken.excess(), _excess += 2_511985);

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
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240509);
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
        assertEq(_wrappedMToken.totalAccruedYield(), 1_240508);
        assertEq(_wrappedMToken.excess(), _excess += 1);

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
        assertEq(_wrappedMToken.totalAccruedYield(), 6_264285);
        assertEq(_wrappedMToken.excess(), _excess += 5_211901);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _aliceBalance + _bobBalance + _bobAccruedYield + _carolBalance + _carolAccruedYield + _daveBalance + _excess
        );

        _unwrap(_alice, _alice, _aliceBalance);

        // Assert Alice (Non-Earner)
        assertEq(_mToken.balanceOf(_alice), _aliceBalance);
        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalance -= _aliceBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_alice), _aliceAccruedYield);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 199_999999);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalSupply(), 299_999998);
        assertEq(_wrappedMToken.totalAccruedYield(), 6_264285);
        assertEq(_wrappedMToken.excess(), _excess -= 1);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _bobBalance + _bobAccruedYield + _carolBalance + _carolAccruedYield + _daveBalance + _excess
        );

        // Accrued yield of Bob is claimed when unwrapping
        _unwrap(_bob, _bob, _bobBalance + _bobAccruedYield);

        // Assert Bob (Earner)
        assertEq(_mToken.balanceOf(_bob), _bobBalance + _bobAccruedYield);
        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalance -= _bobBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_bob), _bobAccruedYield -= _bobAccruedYield);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 100_000000);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalSupply(), 199_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), 2_496407);
        assertEq(_wrappedMToken.excess(), _excess -= 2);

        assertGe(
            _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)),
            _carolBalance + _carolAccruedYield + _daveBalance + _excess
        );

        // Accrued yield of Carol is claimed when unwrapping
        _unwrap(_carol, _carol, _carolBalance + _carolAccruedYield);

        // Assert Carol (Earner)
        assertEq(_mToken.balanceOf(_carol), _carolBalance + _carolAccruedYield);
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalance -= _carolBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_carol), _carolAccruedYield -= _carolAccruedYield);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 0);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 99_999999);
        assertEq(_wrappedMToken.totalSupply(), 99_999999);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), _excess += 3);

        assertGe(_wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)), _daveBalance + _excess);

        _unwrap(_dave, _dave, _daveBalance);

        // Assert Dave (Non-Earner)
        assertEq(_mToken.balanceOf(_dave), _daveBalance);
        assertEq(_wrappedMToken.balanceOf(_dave), _daveBalance -= _daveBalance);
        assertEq(_wrappedMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 0);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 0);
        assertEq(_wrappedMToken.totalSupply(), 0);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), _excess);

        assertGe(_wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)), _excess);

        uint256 vaultStartingBalance_ = _mToken.balanceOf(_vault);

        assertEq(_wrappedMToken.claimExcess(), _excess);
        assertEq(_mToken.balanceOf(_vault), _excess + vaultStartingBalance_);

        // Assert Globals
        assertEq(_wrappedMToken.totalEarningSupply(), 0);
        assertEq(_wrappedMToken.totalNonEarningSupply(), 0);
        assertEq(_wrappedMToken.totalSupply(), 0);
        assertEq(_wrappedMToken.totalAccruedYield(), 0);
        assertEq(_wrappedMToken.excess(), _excess -= _excess);

        assertGe(_wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken)), 0);
    }
}
