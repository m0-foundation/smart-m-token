// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Proxy } from "../../lib/common/src/Proxy.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

import { ISmartMToken } from "../../src/interfaces/ISmartMToken.sol";

import { SmartMToken } from "../../src/SmartMToken.sol";

import { MockEarnerManager, MockM, MockRegistrar } from "../utils/Mocks.sol";

contract StoryTests is Test {
    uint56 internal constant _EXP_SCALED_ONE = 1e12;

    bytes32 internal constant _EARNERS_LIST_NAME = "earners";
    bytes32 internal constant _ADMINS_LIST_NAME = "em_admins";

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");

    address internal _excessDestination = makeAddr("excessDestination");
    address internal _migrationAdmin = makeAddr("migrationAdmin");

    address internal _vault = makeAddr("vault");

    MockEarnerManager internal _earnerManager;
    MockM internal _mToken;
    MockRegistrar internal _registrar;
    SmartMToken internal _implementation;
    ISmartMToken internal _smartMToken;

    function setUp() external {
        _registrar = new MockRegistrar();

        _mToken = new MockM();
        _mToken.setCurrentIndex(_EXP_SCALED_ONE);

        _earnerManager = new MockEarnerManager();

        _implementation = new SmartMToken(
            address(_mToken),
            address(_registrar),
            address(_earnerManager),
            _excessDestination,
            _migrationAdmin
        );

        _smartMToken = ISmartMToken(address(new Proxy(address(_implementation))));
    }

    function test_story() external {
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));
        _earnerManager.setEarnerDetails(_bob, true, 0, address(0));
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.startEarningFor(_alice);

        _smartMToken.startEarningFor(_bob);

        _mToken.setBalanceOf(_alice, 100_000000);

        vm.prank(_alice);
        _smartMToken.wrap(_alice, 100_000000);

        // Assert Alice (Earner)
        assertEq(_smartMToken.balanceOf(_alice), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 100_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalSupply(), 100_000000);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.excess(), 0);

        _mToken.setBalanceOf(_carol, 100_000000);

        vm.prank(_carol);
        _smartMToken.wrap(_carol, 100_000000);

        // Assert Carol (Non-Earner)
        assertEq(_smartMToken.balanceOf(_carol), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 100_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 100_000000);
        assertEq(_smartMToken.totalSupply(), 200_000000);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.excess(), 0);

        _mToken.setCurrentIndex(2 * _EXP_SCALED_ONE);
        _mToken.setBalanceOf(address(_smartMToken), 400_000000);

        // Assert Alice (Earner)
        assertEq(_smartMToken.balanceOf(_alice), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 100_000000);

        // Assert Carol (Non-Earner)
        assertEq(_smartMToken.balanceOf(_carol), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 100_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 100_000000);
        assertEq(_smartMToken.totalSupply(), 200_000000);
        assertEq(_smartMToken.totalAccruedYield(), 100_000000);
        assertEq(_smartMToken.excess(), 100_000000);

        _mToken.setBalanceOf(_bob, 100_000000);

        vm.prank(_bob);
        _smartMToken.wrap(_bob, 100_000000);

        // Assert Bob (Earner)
        assertEq(_smartMToken.balanceOf(_bob), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_bob), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 200_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 100_000000);
        assertEq(_smartMToken.totalSupply(), 300_000000);

        assertEq(_smartMToken.totalAccruedYield(), 100_000000);
        assertEq(_smartMToken.excess(), 100_000000);

        _mToken.setBalanceOf(_dave, 100_000000);

        vm.prank(_dave);
        _smartMToken.wrap(_dave, 100_000000);

        // Assert Dave (Non-Earner)
        assertEq(_smartMToken.balanceOf(_dave), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 200_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 200_000000);
        assertEq(_smartMToken.totalSupply(), 400_000000);
        assertEq(_smartMToken.totalAccruedYield(), 100_000000);
        assertEq(_smartMToken.excess(), 100_000000);

        assertEq(_smartMToken.balanceOf(_alice), 100_000000);

        uint256 yield_ = _smartMToken.claimFor(_alice);

        assertEq(yield_, 100_000000);

        // Assert Alice (Earner)
        assertEq(_smartMToken.balanceOf(_alice), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 300_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 200_000000);
        assertEq(_smartMToken.totalSupply(), 500_000000);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.excess(), 100_000000);

        _mToken.setCurrentIndex(3 * _EXP_SCALED_ONE);
        _mToken.setBalanceOf(address(_smartMToken), 900_000000); // was 600 @ 2.0, so 900 @ 3.0

        // Assert Alice (Earner)
        assertEq(_smartMToken.balanceOf(_alice), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 100_000000);

        // Assert Bob (Earner)
        assertEq(_smartMToken.balanceOf(_bob), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_bob), 50_000000);

        // Assert Carol (Non-Earner)
        assertEq(_smartMToken.balanceOf(_carol), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_carol), 0);

        // Assert Dave (Non-Earner)
        assertEq(_smartMToken.balanceOf(_dave), 100_000000);
        assertEq(_smartMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 300_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 200_000000);
        assertEq(_smartMToken.totalSupply(), 500_000000);
        assertEq(_smartMToken.totalAccruedYield(), 150_000000);
        assertEq(_smartMToken.excess(), 249_999999);

        vm.prank(_alice);
        _smartMToken.transfer(_carol, 100_000000);

        // Assert Alice (Earner)
        assertEq(_smartMToken.balanceOf(_alice), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);

        // Assert Carol (Non-Earner)
        assertEq(_smartMToken.balanceOf(_carol), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 300_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 300_000000);
        assertEq(_smartMToken.totalSupply(), 600_000000);
        assertEq(_smartMToken.totalAccruedYield(), 50_000001);
        assertEq(_smartMToken.excess(), 249_999999);

        vm.prank(_dave);
        _smartMToken.transfer(_bob, 50_000000);

        // Assert Bob (Earner)
        assertEq(_smartMToken.balanceOf(_bob), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_bob), 0);

        // Assert Dave (Non-Earner)
        assertEq(_smartMToken.balanceOf(_dave), 50_000000);
        assertEq(_smartMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 400_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 250_000000);
        assertEq(_smartMToken.totalSupply(), 650_000000);
        assertEq(_smartMToken.totalAccruedYield(), 2);
        assertEq(_smartMToken.excess(), 249_999996);

        _mToken.setCurrentIndex(4 * _EXP_SCALED_ONE);
        _mToken.setBalanceOf(address(_smartMToken), 1_200_000000); // was 900 @ 3.0, so 1200 @ 4.0

        // Assert Alice (Earner)
        assertEq(_smartMToken.balanceOf(_alice), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 66_666664);

        // Assert Bob (Earner)
        assertEq(_smartMToken.balanceOf(_bob), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_bob), 66_666664);

        // Assert Carol (Non-Earner)
        assertEq(_smartMToken.balanceOf(_carol), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_carol), 0);

        // Assert Dave (Non-Earner)
        assertEq(_smartMToken.balanceOf(_dave), 50_000000);
        assertEq(_smartMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 400_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 250_000000);
        assertEq(_smartMToken.totalSupply(), 650_000000);
        assertEq(_smartMToken.totalAccruedYield(), 133_333336);
        assertEq(_smartMToken.excess(), 416_666664);

        _earnerManager.setEarnerDetails(_alice, false, 0, address(0));

        _smartMToken.stopEarningFor(_alice);

        // Assert Alice (Non-Earner)
        assertEq(_smartMToken.balanceOf(_alice), 266_666664);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 200_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 516_666664);
        assertEq(_smartMToken.totalSupply(), 716_666664);
        assertEq(_smartMToken.totalAccruedYield(), 66_666672);
        assertEq(_smartMToken.excess(), 416_666664);

        _earnerManager.setEarnerDetails(_carol, true, 0, address(0));

        _smartMToken.startEarningFor(_carol);

        // Assert Carol (Earner)
        assertEq(_smartMToken.balanceOf(_carol), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 400_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 316_666664);
        assertEq(_smartMToken.totalSupply(), 716_666664);
        assertEq(_smartMToken.totalAccruedYield(), 66_666672);
        assertEq(_smartMToken.excess(), 416_666664);

        _mToken.setCurrentIndex(5 * _EXP_SCALED_ONE);
        _mToken.setBalanceOf(address(_smartMToken), 1_500_000000); // was 1200 @ 4.0, so 1500 @ 5.0

        // Assert Alice (Non-Earner)
        assertEq(_smartMToken.balanceOf(_alice), 266_666664);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);

        // Assert Bob (Earner)
        assertEq(_smartMToken.balanceOf(_bob), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_bob), 133_333330);

        // Assert Carol (Earner)
        assertEq(_smartMToken.balanceOf(_carol), 200_000000);
        assertEq(_smartMToken.accruedYieldOf(_carol), 50_000000);

        // Assert Dave (Non-Earner)
        assertEq(_smartMToken.balanceOf(_dave), 50_000000);
        assertEq(_smartMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 400_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 316_666664);
        assertEq(_smartMToken.totalSupply(), 716_666664);
        assertEq(_smartMToken.totalAccruedYield(), 183_333340);
        assertEq(_smartMToken.excess(), 599_999995);

        vm.prank(_alice);
        _smartMToken.unwrap(_alice, 266_666664);

        // Assert Alice (Non-Earner)
        assertEq(_smartMToken.balanceOf(_alice), 0);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 400_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 50_000000);
        assertEq(_smartMToken.totalSupply(), 450_000000);
        assertEq(_smartMToken.totalAccruedYield(), 183_333340);
        assertEq(_smartMToken.excess(), 600_000000);

        vm.prank(_bob);
        _smartMToken.unwrap(_bob, 333_333330);

        // Assert Bob (Earner)
        assertEq(_smartMToken.balanceOf(_bob), 0);
        assertEq(_smartMToken.accruedYieldOf(_bob), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 200_000000);
        assertEq(_smartMToken.totalNonEarningSupply(), 50_000000);
        assertEq(_smartMToken.totalSupply(), 250_000000);
        assertEq(_smartMToken.totalAccruedYield(), 50_000010);
        assertEq(_smartMToken.excess(), 600_000000);

        vm.prank(_carol);
        _smartMToken.unwrap(_carol, 250_000000);

        // Assert Carol (Earner)
        assertEq(_smartMToken.balanceOf(_carol), 0);
        assertEq(_smartMToken.accruedYieldOf(_carol), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.totalNonEarningSupply(), 50_000000);
        assertEq(_smartMToken.totalSupply(), 50_000000);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.excess(), 600_000010);

        vm.prank(_dave);
        _smartMToken.unwrap(_dave, 50_000000);

        // Assert Dave (Non-Earner)
        assertEq(_smartMToken.balanceOf(_dave), 0);
        assertEq(_smartMToken.accruedYieldOf(_dave), 0);

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalSupply(), 0);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.excess(), 600_000010);

        _smartMToken.claimExcess();

        // Assert Globals
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalSupply(), 0);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.excess(), 0);
    }

    function test_noExcessCreep() external {
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));
        _earnerManager.setEarnerDetails(_bob, true, 0, address(0));
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_EXP_SCALED_ONE + 3e11 - 1);

        _smartMToken.enableEarning();
        _smartMToken.startEarningFor(_alice);

        _mToken.setBalanceOf(_alice, 1_000000);

        for (uint256 i_; i_ < 100; ++i_) {
            vm.prank(_alice);
            _smartMToken.wrap(_alice, 9);

            assertLe(_smartMToken.balanceOf(_alice) + _smartMToken.excess(), _mToken.balanceOf(address(_smartMToken)));
        }

        _smartMToken.claimExcess();

        uint256 aliceBalance_ = _smartMToken.balanceOf(_alice);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, aliceBalance_);

        assertLe(_smartMToken.balanceOf(_bob) + _smartMToken.excess(), _mToken.balanceOf(address(_smartMToken)));

        vm.prank(_bob);
        _smartMToken.unwrap(_bob);
    }

    function test_dustWrapping() external {
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));
        _earnerManager.setEarnerDetails(_bob, true, 0, address(0));
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_EXP_SCALED_ONE + 1);

        _smartMToken.enableEarning();
        _smartMToken.startEarningFor(_alice);

        _mToken.setBalanceOf(_alice, 1_000000);

        for (uint256 i_; i_ < 100; ++i_) {
            vm.prank(_alice);
            _smartMToken.wrap(_alice, 1);

            assertLe(_smartMToken.balanceOf(_alice) + _smartMToken.excess(), _mToken.balanceOf(address(_smartMToken)));
        }

        _mToken.setCurrentIndex(_EXP_SCALED_ONE + (_EXP_SCALED_ONE / 10));

        assertGe(_smartMToken.totalAccruedYield(), _smartMToken.accruedYieldOf(_alice));
    }
}
