// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IndexingMath } from "../../lib/common/src/libs/IndexingMath.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IERC20Extended } from "../../lib/common/src/interfaces/IERC20Extended.sol";

import { UIntMath } from "../../lib/common/src/libs/UIntMath.sol";
import { Proxy } from "../../lib/common/src/Proxy.sol";
import { Test, console2 } from "../../lib/forge-std/src/Test.sol";

import { ISmartMToken } from "../../src/interfaces/ISmartMToken.sol";

import { MockEarnerManager, MockM, MockRegistrar } from "../utils/Mocks.sol";
import { SmartMTokenHarness } from "../utils/SmartMTokenHarness.sol";

// TODO: Test for `totalAccruedYield()`.
// TODO: All operations involving earners should include demonstration of accrued yield being added to their balance.
// TODO: Add relevant unit tests while earning enabled/disabled.

contract SmartMTokenTests is Test {
    uint56 internal constant _EXP_SCALED_ONE = 1e12;
    uint56 internal constant _ONE_HUNDRED_PERCENT = 10_000;
    bytes32 internal constant _CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX = "wm_claim_override_recipient";

    bytes32 internal constant _EARNERS_LIST_NAME = "earners";

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _charlie = makeAddr("charlie");
    address internal _david = makeAddr("david");

    address internal _excessDestination = makeAddr("excessDestination");
    address internal _migrationAdmin = makeAddr("migrationAdmin");

    address[] internal _accounts = [_alice, _bob, _charlie, _david];

    uint128 internal _currentIndex;

    MockEarnerManager internal _earnerManager;
    MockM internal _mToken;
    MockRegistrar internal _registrar;
    SmartMTokenHarness internal _implementation;
    SmartMTokenHarness internal _smartMToken;

    function setUp() external {
        _registrar = new MockRegistrar();

        _mToken = new MockM();
        _mToken.setCurrentIndex(_EXP_SCALED_ONE);

        _earnerManager = new MockEarnerManager();

        _implementation = new SmartMTokenHarness(
            address(_mToken),
            address(_registrar),
            address(_earnerManager),
            _excessDestination,
            _migrationAdmin
        );

        _smartMToken = SmartMTokenHarness(address(new Proxy(address(_implementation))));

        _mToken.setCurrentIndex(_currentIndex = 1_100000068703);
    }

    /* ============ constructor ============ */
    function test_constructor() external view {
        assertEq(_smartMToken.migrationAdmin(), _migrationAdmin);
        assertEq(_smartMToken.mToken(), address(_mToken));
        assertEq(_smartMToken.registrar(), address(_registrar));
        assertEq(_smartMToken.excessDestination(), _excessDestination);
        assertEq(_smartMToken.name(), "Smart M by M^0");
        assertEq(_smartMToken.symbol(), "MSMART");
        assertEq(_smartMToken.decimals(), 6);
        assertEq(_smartMToken.implementation(), address(_implementation));
    }

    function test_constructor_zeroMToken() external {
        vm.expectRevert(ISmartMToken.ZeroMToken.selector);
        new SmartMTokenHarness(address(0), address(0), address(0), address(0), address(0));
    }

    function test_constructor_zeroRegistrar() external {
        vm.expectRevert(ISmartMToken.ZeroRegistrar.selector);
        new SmartMTokenHarness(address(_mToken), address(0), address(0), address(0), address(0));
    }

    function test_constructor_zeroEarnerManager() external {
        vm.expectRevert(ISmartMToken.ZeroEarnerManager.selector);
        new SmartMTokenHarness(address(_mToken), address(_registrar), address(0), address(0), address(0));
    }

    function test_constructor_zeroExcessDestination() external {
        vm.expectRevert(ISmartMToken.ZeroExcessDestination.selector);
        new SmartMTokenHarness(address(_mToken), address(_registrar), address(_earnerManager), address(0), address(0));
    }

    function test_constructor_zeroMigrationAdmin() external {
        vm.expectRevert(ISmartMToken.ZeroMigrationAdmin.selector);
        new SmartMTokenHarness(
            address(_mToken),
            address(_registrar),
            address(_earnerManager),
            _excessDestination,
            address(0)
        );
    }

    function test_constructor_zeroImplementation() external {
        vm.expectRevert();
        SmartMTokenHarness(address(new Proxy(address(0))));
    }

    /* ============ _wrap ============ */
    function test_internalWrap_insufficientAmount() external {
        vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, 0));

        _smartMToken.internalWrap(_alice, _alice, 0);
    }

    function test_internalWrap_invalidRecipient() external {
        _mToken.setBalanceOf(_alice, 1_000);

        vm.expectRevert(ISmartMToken.ZeroAccount.selector);

        _smartMToken.internalWrap(_alice, address(0), 1_000);
    }

    function test_internalWrap_toNonEarner() external {
        _mToken.setBalanceOf(_alice, 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1_000);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 1_000), 1_000);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.totalNonEarningSupply(), 1_000);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 0);
    }

    function test_internalWrap_toEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 0, _EXP_SCALED_ONE, false, false);

        _mToken.setBalanceOf(_alice, 1_002);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 999);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 999), 999);

        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 999);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 909);
        assertEq(_smartMToken.totalEarningSupply(), 999);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 1), 1);

        // No change due to principal round down on wrap.
        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 910);
        assertEq(_smartMToken.totalEarningSupply(), 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 2);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 2), 2);

        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 1_002);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 912);
        assertEq(_smartMToken.totalEarningSupply(), 1_002);
    }

    /* ============ wrap ============ */
    function test_wrap_invalidAmount() external {
        vm.expectRevert(UIntMath.InvalidUInt240.selector);

        vm.prank(_alice);
        _smartMToken.wrap(_alice, uint256(type(uint240).max) + 1);
    }

    function testFuzz_wrap(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 accountIndex_,
        uint128 currentIndex_
    ) external {
        accountEarning_ = earningEnabled_ && accountEarning_;

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.enableEarning();
        }

        accountIndex_ = uint128(bound(accountIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));

        if (accountEarning_) {
            _smartMToken.setAccountOf(_alice, balance_, accountIndex_, false, false);
            _smartMToken.setTotalEarningSupply(balance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(balance_, accountIndex_)
            );
        } else {
            _smartMToken.setAccountOf(_alice, balance_);
            _smartMToken.setTotalNonEarningSupply(balance_);
        }

        currentIndex_ = uint128(bound(currentIndex_, accountIndex_, 10 * _EXP_SCALED_ONE));
        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(currentIndex_) - balance_));

        _mToken.setCurrentIndex(_currentIndex = currentIndex_);
        _mToken.setBalanceOf(_alice, wrapAmount_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrap(_alice, wrapAmount_);

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + accruedYield_ + wrapAmount_);

        assertEq(
            accountEarning_ ? _smartMToken.totalEarningSupply() : _smartMToken.totalNonEarningSupply(),
            _smartMToken.balanceOf(_alice)
        );
    }

    /* ============ wrap entire balance ============ */
    function test_wrap_entireBalance_invalidAmount() external {
        _mToken.setBalanceOf(_alice, uint256(type(uint240).max) + 1);

        vm.expectRevert(UIntMath.InvalidUInt240.selector);

        vm.prank(_alice);
        _smartMToken.wrap(_alice, uint256(type(uint240).max) + 1);
    }

    function testFuzz_wrap_entireBalance(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 accountIndex_,
        uint128 currentIndex_
    ) external {
        accountEarning_ = earningEnabled_ && accountEarning_;

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.enableEarning();
        }

        accountIndex_ = uint128(bound(accountIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));

        if (accountEarning_) {
            _smartMToken.setAccountOf(_alice, balance_, accountIndex_, false, false);
            _smartMToken.setTotalEarningSupply(balance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(balance_, accountIndex_)
            );
        } else {
            _smartMToken.setAccountOf(_alice, balance_);
            _smartMToken.setTotalNonEarningSupply(balance_);
        }

        currentIndex_ = uint128(bound(currentIndex_, accountIndex_, 10 * _EXP_SCALED_ONE));
        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(currentIndex_) - balance_));

        _mToken.setCurrentIndex(_currentIndex = currentIndex_);
        _mToken.setBalanceOf(_alice, wrapAmount_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrap(_alice);

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + accruedYield_ + wrapAmount_);

        assertEq(
            accountEarning_ ? _smartMToken.totalEarningSupply() : _smartMToken.totalNonEarningSupply(),
            _smartMToken.balanceOf(_alice)
        );
    }

    /* ============ wrapWithPermit vrs ============ */
    function test_wrapWithPermit_vrs_invalidAmount() external {
        vm.expectRevert(UIntMath.InvalidUInt240.selector);

        vm.prank(_alice);
        _smartMToken.wrapWithPermit(_alice, uint256(type(uint240).max) + 1, 0, 0, bytes32(0), bytes32(0));
    }

    function testFuzz_wrapWithPermit_vrs(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 accountIndex_,
        uint128 currentIndex_
    ) external {
        accountEarning_ = earningEnabled_ && accountEarning_;

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.enableEarning();
        }

        accountIndex_ = uint128(bound(accountIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));

        if (accountEarning_) {
            _smartMToken.setAccountOf(_alice, balance_, accountIndex_, false, false);
            _smartMToken.setTotalEarningSupply(balance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(balance_, accountIndex_)
            );
        } else {
            _smartMToken.setAccountOf(_alice, balance_);
            _smartMToken.setTotalNonEarningSupply(balance_);
        }

        currentIndex_ = uint128(bound(currentIndex_, accountIndex_, 10 * _EXP_SCALED_ONE));
        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(currentIndex_) - balance_));

        _mToken.setCurrentIndex(_currentIndex = currentIndex_);
        _mToken.setBalanceOf(_alice, wrapAmount_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrapWithPermit(_alice, wrapAmount_, 0, 0, bytes32(0), bytes32(0));

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + accruedYield_ + wrapAmount_);

        assertEq(
            accountEarning_ ? _smartMToken.totalEarningSupply() : _smartMToken.totalNonEarningSupply(),
            _smartMToken.balanceOf(_alice)
        );
    }

    /* ============ wrapWithPermit signature ============ */
    function test_wrapWithPermit_signature_invalidAmount() external {
        vm.expectRevert(UIntMath.InvalidUInt240.selector);

        vm.prank(_alice);
        _smartMToken.wrapWithPermit(_alice, uint256(type(uint240).max) + 1, 0, hex"");
    }

    function testFuzz_wrapWithPermit_signature(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 accountIndex_,
        uint128 currentIndex_
    ) external {
        accountEarning_ = earningEnabled_ && accountEarning_;

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.enableEarning();
        }

        accountIndex_ = uint128(bound(accountIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));

        if (accountEarning_) {
            _smartMToken.setAccountOf(_alice, balance_, accountIndex_, false, false);
            _smartMToken.setTotalEarningSupply(balance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(balance_, accountIndex_)
            );
        } else {
            _smartMToken.setAccountOf(_alice, balance_);
            _smartMToken.setTotalNonEarningSupply(balance_);
        }

        currentIndex_ = uint128(bound(currentIndex_, accountIndex_, 10 * _EXP_SCALED_ONE));
        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(currentIndex_) - balance_));

        _mToken.setCurrentIndex(_currentIndex = currentIndex_);
        _mToken.setBalanceOf(_alice, wrapAmount_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrapWithPermit(_alice, wrapAmount_, 0, hex"");

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + accruedYield_ + wrapAmount_);

        assertEq(
            accountEarning_ ? _smartMToken.totalEarningSupply() : _smartMToken.totalNonEarningSupply(),
            _smartMToken.balanceOf(_alice)
        );
    }

    /* ============ _unwrap ============ */
    function test_internalUnwrap_insufficientAmount() external {
        vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, 0));

        _smartMToken.internalUnwrap(_alice, _alice, 0);
    }

    function test_internalUnwrap_insufficientBalance_fromNonEarner() external {
        _smartMToken.setAccountOf(_alice, 999);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, 999, 1_000));
        _smartMToken.internalUnwrap(_alice, _alice, 1_000);
    }

    function test_internalUnwrap_insufficientBalance_fromEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 999, _currentIndex, false, false);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, 999, 1_000));
        _smartMToken.internalUnwrap(_alice, _alice, 1_000);
    }

    function test_internalUnwrap_fromNonEarner() external {
        _smartMToken.setTotalNonEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000);

        _mToken.setBalanceOf(address(_smartMToken), 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 500);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 500), 500);

        assertEq(_smartMToken.balanceOf(_alice), 500);
        assertEq(_smartMToken.totalNonEarningSupply(), 500);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 0);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 500);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 500), 500);

        assertEq(_smartMToken.balanceOf(_alice), 0);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 0);
    }

    function test_internalUnwrap_fromEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setPrincipalOfTotalEarningSupply(909);
        _smartMToken.setTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, _currentIndex, false, false);

        _mToken.setBalanceOf(address(_smartMToken), 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 1);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 1), 0);

        // Change due to principal round up on unwrap.
        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 999);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), 999);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 999);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 999), 998);

        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 0);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), 0);
    }

    /* ============ unwrap ============ */
    function test_unwrap_invalidAmount() external {
        vm.expectRevert(UIntMath.InvalidUInt240.selector);

        vm.prank(_alice);
        _smartMToken.unwrap(_alice, uint256(type(uint240).max) + 1);
    }

    function testFuzz_unwrap(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balance_,
        uint240 unwrapAmount_,
        uint128 accountIndex_,
        uint128 currentIndex_
    ) external {
        accountEarning_ = earningEnabled_ && accountEarning_;

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.enableEarning();
        }

        accountIndex_ = uint128(bound(accountIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));

        if (accountEarning_) {
            _smartMToken.setAccountOf(_alice, balance_, accountIndex_, false, false);
            _smartMToken.setTotalEarningSupply(balance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(balance_, accountIndex_)
            );
        } else {
            _smartMToken.setAccountOf(_alice, balance_);
            _smartMToken.setTotalNonEarningSupply(balance_);
        }

        currentIndex_ = uint128(bound(currentIndex_, accountIndex_, 10 * _EXP_SCALED_ONE));
        unwrapAmount_ = uint240(bound(unwrapAmount_, 0, 2 * balance_));

        _mToken.setCurrentIndex(_currentIndex = currentIndex_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        _mToken.setBalanceOf(address(_smartMToken), balance_ + accruedYield_);

        if (unwrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else if (unwrapAmount_ > balance_ + accruedYield_) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISmartMToken.InsufficientBalance.selector,
                    _alice,
                    balance_ + accruedYield_,
                    unwrapAmount_
                )
            );
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, address(0), unwrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.unwrap(_alice, unwrapAmount_);

        if ((unwrapAmount_ == 0) || (unwrapAmount_ > balance_ + accruedYield_)) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + accruedYield_ - unwrapAmount_);

        assertEq(
            accountEarning_ ? _smartMToken.totalEarningSupply() : _smartMToken.totalNonEarningSupply(),
            _smartMToken.balanceOf(_alice)
        );
    }

    /* ============ unwrap entire balance ============ */
    function testFuzz_unwrap_entireBalance(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balance_,
        uint128 accountIndex_,
        uint128 currentIndex_
    ) external {
        accountEarning_ = earningEnabled_ && accountEarning_;

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.enableEarning();
        }

        accountIndex_ = uint128(bound(accountIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));

        if (accountEarning_) {
            _smartMToken.setAccountOf(_alice, balance_, accountIndex_, false, false);
            _smartMToken.setTotalEarningSupply(balance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(balance_, accountIndex_)
            );
        } else {
            _smartMToken.setAccountOf(_alice, balance_);
            _smartMToken.setTotalNonEarningSupply(balance_);
        }

        currentIndex_ = uint128(bound(currentIndex_, accountIndex_, 10 * _EXP_SCALED_ONE));

        _mToken.setCurrentIndex(_currentIndex = currentIndex_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        _mToken.setBalanceOf(address(_smartMToken), balance_ + accruedYield_);

        if (balance_ + accruedYield_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, address(0), balance_ + accruedYield_);
        }

        vm.startPrank(_alice);
        _smartMToken.unwrap(_alice);

        if (balance_ + accruedYield_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), 0);

        assertEq(accountEarning_ ? _smartMToken.totalEarningSupply() : _smartMToken.totalNonEarningSupply(), 0);
    }

    /* ============ claimFor ============ */
    function test_claimFor_nonEarner() external {
        _smartMToken.setAccountOf(_alice, 1_000);

        vm.prank(_alice);
        assertEq(_smartMToken.claimFor(_alice), 0);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
    }

    function test_claimFor_earner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 1_000, _EXP_SCALED_ONE, false, false);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        vm.expectEmit();
        emit ISmartMToken.Claimed(_alice, _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 100);

        assertEq(_smartMToken.claimFor(_alice), 100);

        assertEq(_smartMToken.balanceOf(_alice), 1_100);
    }

    function test_claimFor_earner_withOverrideRecipient() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _registrar.set(
            keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
            bytes32(uint256(uint160(_bob)))
        );

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 1_000, _EXP_SCALED_ONE, false, false);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        vm.expectEmit();
        emit ISmartMToken.Claimed(_alice, _bob, 100);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 100);

        assertEq(_smartMToken.claimFor(_alice), 100);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.balanceOf(_bob), 100);
    }

    function test_claimFor_earner_withFee() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 1_000, _EXP_SCALED_ONE, true, false);

        _earnerManager.setEarnerDetails(_alice, true, 1_500, _bob);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        vm.expectEmit();
        emit ISmartMToken.Claimed(_alice, _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 15);

        assertEq(_smartMToken.claimFor(_alice), 100);

        assertEq(_smartMToken.balanceOf(_alice), 1_085);
        assertEq(_smartMToken.balanceOf(_bob), 15);
    }

    function test_claimFor_earner_withFeeAboveOneHundredPercent() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 1_000, _EXP_SCALED_ONE, true, false);

        _earnerManager.setEarnerDetails(_alice, true, type(uint16).max, _bob);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        vm.expectEmit();
        emit ISmartMToken.Claimed(_alice, _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 100);

        assertEq(_smartMToken.claimFor(_alice), 100);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.balanceOf(_bob), 100);
    }

    function test_claimFor_earner_withOverrideRecipientAndFee() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _registrar.set(
            keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
            bytes32(uint256(uint160(_charlie)))
        );

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 1_000, _EXP_SCALED_ONE, true, false);

        _earnerManager.setEarnerDetails(_alice, true, 1_500, _bob);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        vm.expectEmit();
        emit ISmartMToken.Claimed(_alice, _charlie, 100);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 15);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _charlie, 85);

        assertEq(_smartMToken.claimFor(_alice), 100);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.balanceOf(_bob), 15);
        assertEq(_smartMToken.balanceOf(_charlie), 85);
    }

    function testFuzz_claimFor(
        uint240 balance_,
        uint128 accountIndex_,
        uint128 index_,
        bool claimOverride_,
        uint16 feeRate_
    ) external {
        accountIndex_ = uint128(bound(index_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));
        index_ = uint128(bound(index_, accountIndex_, 10 * _EXP_SCALED_ONE));

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        if (claimOverride_) {
            _registrar.set(
                keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
                bytes32(uint256(uint160(_charlie)))
            );
        }

        _smartMToken.enableEarning();

        _smartMToken.setTotalEarningSupply(balance_);

        _smartMToken.setAccountOf(_alice, balance_, accountIndex_, feeRate_ != 0, false);

        if (feeRate_ != 0) {
            _earnerManager.setEarnerDetails(_alice, true, feeRate_, _bob);
        }

        _mToken.setCurrentIndex(index_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        if (accruedYield_ != 0) {
            vm.expectEmit();
            emit ISmartMToken.Claimed(_alice, claimOverride_ ? _charlie : _alice, accruedYield_);

            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, accruedYield_);
        }

        uint240 fee_ = (accruedYield_ * (feeRate_ > _ONE_HUNDRED_PERCENT ? _ONE_HUNDRED_PERCENT : feeRate_)) /
            _ONE_HUNDRED_PERCENT;

        if (fee_ != 0) {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, _bob, fee_);
        }

        if (claimOverride_ && (accruedYield_ - fee_ != 0)) {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, _charlie, accruedYield_ - fee_);
        }

        assertEq(_smartMToken.claimFor(_alice), accruedYield_);

        assertEq(
            _smartMToken.totalSupply(),
            _smartMToken.balanceOf(_alice) + _smartMToken.balanceOf(_bob) + _smartMToken.balanceOf(_charlie)
        );
    }

    /* ============ claimExcess ============ */
    function testFuzz_claimExcess(
        uint128 index_,
        uint240 totalNonEarningSupply_,
        uint112 principalOfTotalEarningSupply_,
        uint240 mBalance_
    ) external {
        index_ = uint128(bound(index_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));

        totalNonEarningSupply_ = uint240(bound(totalNonEarningSupply_, 0, _getMaxAmount(index_)));

        uint240 totalEarningSupply_ = uint112(bound(principalOfTotalEarningSupply_, 0, _getMaxAmount(index_)));

        principalOfTotalEarningSupply_ = uint112(totalEarningSupply_ / index_);

        mBalance_ = uint240(bound(mBalance_, totalNonEarningSupply_ + totalEarningSupply_, type(uint240).max));

        _mToken.setBalanceOf(address(_smartMToken), mBalance_);
        _smartMToken.setTotalNonEarningSupply(totalNonEarningSupply_);
        _smartMToken.setPrincipalOfTotalEarningSupply(principalOfTotalEarningSupply_);

        _mToken.setCurrentIndex(index_);

        uint240 expectedExcess_ = _smartMToken.excess();

        vm.expectCall(
            address(_mToken),
            abi.encodeCall(_mToken.transfer, (_smartMToken.excessDestination(), expectedExcess_))
        );

        vm.expectEmit();
        emit ISmartMToken.ExcessClaimed(expectedExcess_);

        assertEq(_smartMToken.claimExcess(), expectedExcess_);
        assertEq(_smartMToken.excess(), 0);
    }

    /* ============ transfer ============ */
    function test_transfer_invalidRecipient() external {
        _smartMToken.setAccountOf(_alice, 1_000);

        vm.expectRevert(ISmartMToken.ZeroAccount.selector);

        vm.prank(_alice);
        _smartMToken.transfer(address(0), 1_000);
    }

    function test_transfer_insufficientBalance_fromNonEarner_toNonEarner() external {
        _smartMToken.setAccountOf(_alice, 999);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, 999, 1_000));
        vm.prank(_alice);
        _smartMToken.transfer(_bob, 1_000);
    }

    function test_transfer_insufficientBalance_fromEarner_toNonEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 999, _currentIndex, false, false);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, 999, 1_000));
        vm.prank(_alice);
        _smartMToken.transfer(_bob, 1_000);
    }

    function test_transfer_fromNonEarner_toNonEarner() external {
        _smartMToken.setTotalNonEarningSupply(1_500);

        _smartMToken.setAccountOf(_alice, 1_000);
        _smartMToken.setAccountOf(_bob, 500);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 500);

        assertEq(_smartMToken.balanceOf(_alice), 500);

        assertEq(_smartMToken.balanceOf(_bob), 1_000);

        assertEq(_smartMToken.totalNonEarningSupply(), 1_500);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 0);
    }

    function testFuzz_transfer_fromNonEarner_toNonEarner(
        uint256 supply_,
        uint256 aliceBalance_,
        uint256 transferAmount_
    ) external {
        supply_ = bound(supply_, 1, type(uint112).max);
        aliceBalance_ = bound(aliceBalance_, 1, supply_);
        transferAmount_ = bound(transferAmount_, 1, aliceBalance_);
        uint256 bobBalance = supply_ - aliceBalance_;

        _smartMToken.setTotalNonEarningSupply(supply_);

        _smartMToken.setAccountOf(_alice, aliceBalance_);
        _smartMToken.setAccountOf(_bob, bobBalance);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, transferAmount_);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, transferAmount_);

        assertEq(_smartMToken.balanceOf(_alice), aliceBalance_ - transferAmount_);
        assertEq(_smartMToken.balanceOf(_bob), bobBalance + transferAmount_);

        assertEq(_smartMToken.totalNonEarningSupply(), supply_);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 0);
    }

    function test_transfer_fromEarner_toNonEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setPrincipalOfTotalEarningSupply(909);
        _smartMToken.setTotalEarningSupply(1_000);

        _smartMToken.setTotalNonEarningSupply(500);

        _smartMToken.setAccountOf(_alice, 1_000, _currentIndex, false, false);
        _smartMToken.setAccountOf(_bob, 500);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 500);

        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 500);

        assertEq(_smartMToken.balanceOf(_bob), 1_000);

        assertEq(_smartMToken.totalNonEarningSupply(), 1_000);
        assertEq(_smartMToken.totalEarningSupply(), 500);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 1);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 1);

        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 499);

        assertEq(_smartMToken.balanceOf(_bob), 1_001);

        assertEq(_smartMToken.totalNonEarningSupply(), 1_001);
        assertEq(_smartMToken.totalEarningSupply(), 499);
    }

    function test_transfer_fromNonEarner_toEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setPrincipalOfTotalEarningSupply(454);
        _smartMToken.setTotalEarningSupply(500);

        _smartMToken.setTotalNonEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000);
        _smartMToken.setAccountOf(_bob, 500, _currentIndex, false, false);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 500);

        assertEq(_smartMToken.balanceOf(_alice), 500);

        assertEq(_smartMToken.lastIndexOf(_bob), _currentIndex);
        assertEq(_smartMToken.balanceOf(_bob), 1_000);

        assertEq(_smartMToken.totalNonEarningSupply(), 500);
        assertEq(_smartMToken.totalEarningSupply(), 1_000);
    }

    function test_transfer_fromEarner_toEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setPrincipalOfTotalEarningSupply(1_363);
        _smartMToken.setTotalEarningSupply(1_500);

        _smartMToken.setAccountOf(_alice, 1_000, _currentIndex, false, false);
        _smartMToken.setAccountOf(_bob, 500, _currentIndex, false, false);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 500);

        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 500);

        assertEq(_smartMToken.lastIndexOf(_bob), _currentIndex);
        assertEq(_smartMToken.balanceOf(_bob), 1_000);

        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), 1_500);
    }

    function test_transfer_nonEarnerToSelf() external {
        _smartMToken.setTotalNonEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _alice, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_alice, 500);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        assertEq(_smartMToken.totalNonEarningSupply(), 1_000);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.principalOfTotalEarningSupply(), 0);
    }

    function test_transfer_earnerToSelf() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setPrincipalOfTotalEarningSupply(909);
        _smartMToken.setTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, _currentIndex, false, false);

        _mToken.setCurrentIndex((_currentIndex * 5) / 3); // 1_833333447838

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 666);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _alice, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_alice, 500);

        assertEq(_smartMToken.balanceOf(_alice), 1_666);
    }

    function testFuzz_transfer(
        bool earningEnabled_,
        bool aliceEarning_,
        bool bobEarning_,
        uint240 aliceBalance_,
        uint240 bobBalance_,
        uint128 aliceIndex_,
        uint128 bobIndex_,
        uint128 currentIndex_,
        uint240 amount_
    ) external {
        aliceEarning_ = earningEnabled_ && aliceEarning_;
        bobEarning_ = earningEnabled_ && bobEarning_;

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.enableEarning();
        }

        aliceIndex_ = uint128(bound(aliceIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        aliceBalance_ = uint240(bound(aliceBalance_, 0, _getMaxAmount(aliceIndex_) / 4));

        if (aliceEarning_) {
            _smartMToken.setAccountOf(_alice, aliceBalance_, aliceIndex_, false, false);
            _smartMToken.setTotalEarningSupply(aliceBalance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(aliceBalance_, aliceIndex_)
            );
        } else {
            _smartMToken.setAccountOf(_alice, aliceBalance_);
            _smartMToken.setTotalNonEarningSupply(aliceBalance_);
        }

        bobIndex_ = uint128(bound(bobIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        bobBalance_ = uint240(bound(bobBalance_, 0, _getMaxAmount(bobIndex_) / 4));

        if (bobEarning_) {
            _smartMToken.setAccountOf(_bob, bobBalance_, bobIndex_, false, false);
            _smartMToken.setTotalEarningSupply(_smartMToken.totalEarningSupply() + bobBalance_);

            _smartMToken.setPrincipalOfTotalEarningSupply(
                IndexingMath.getPrincipalAmountRoundedDown(
                    _smartMToken.totalEarningSupply() + bobBalance_,
                    aliceIndex_ > bobIndex_ ? aliceIndex_ : bobIndex_
                )
            );
        } else {
            _smartMToken.setAccountOf(_bob, bobBalance_);
            _smartMToken.setTotalNonEarningSupply(_smartMToken.totalNonEarningSupply() + bobBalance_);
        }

        currentIndex_ = uint128(
            bound(currentIndex_, aliceIndex_ > bobIndex_ ? aliceIndex_ : bobIndex_, 10 * _EXP_SCALED_ONE)
        );

        _mToken.setCurrentIndex(_currentIndex = currentIndex_);

        uint240 aliceAccruedYield_ = _smartMToken.accruedYieldOf(_alice);
        uint240 bobAccruedYield_ = _smartMToken.accruedYieldOf(_bob);

        amount_ = uint240(bound(amount_, 0, aliceBalance_ + aliceAccruedYield_));

        if (amount_ > aliceBalance_ + aliceAccruedYield_) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISmartMToken.InsufficientBalance.selector,
                    _alice,
                    aliceBalance_ + aliceAccruedYield_,
                    amount_
                )
            );
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, _bob, amount_);
        }

        vm.prank(_alice);
        _smartMToken.transfer(_bob, amount_);

        if (amount_ > aliceBalance_ + aliceAccruedYield_) return;

        assertEq(_smartMToken.balanceOf(_alice), aliceBalance_ + aliceAccruedYield_ - amount_);
        assertEq(_smartMToken.balanceOf(_bob), bobBalance_ + bobAccruedYield_ + amount_);

        if (aliceEarning_ && bobEarning_) {
            assertEq(
                _smartMToken.totalEarningSupply(),
                aliceBalance_ + aliceAccruedYield_ + bobBalance_ + bobAccruedYield_
            );
        } else if (aliceEarning_) {
            assertEq(_smartMToken.totalEarningSupply(), aliceBalance_ + aliceAccruedYield_ - amount_);
            assertEq(_smartMToken.totalNonEarningSupply(), bobBalance_ + bobAccruedYield_ + amount_);
        } else if (bobEarning_) {
            assertEq(_smartMToken.totalNonEarningSupply(), aliceBalance_ + aliceAccruedYield_ - amount_);
            assertEq(_smartMToken.totalEarningSupply(), bobBalance_ + bobAccruedYield_ + amount_);
        } else {
            assertEq(
                _smartMToken.totalNonEarningSupply(),
                aliceBalance_ + aliceAccruedYield_ + bobBalance_ + bobAccruedYield_
            );
        }
    }

    /* ============ startEarningFor ============ */
    function test_startEarningFor_earningIsDisabled() external {
        vm.expectRevert(ISmartMToken.EarningIsDisabled.selector);
        _smartMToken.startEarningFor(_alice);
    }

    function test_startEarningFor_notApprovedEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.NotApprovedEarner.selector, _alice));
        _smartMToken.startEarningFor(_alice);
    }

    function test_startEarning_overflow() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        uint256 aliceBalance_ = uint256(type(uint112).max) + 20;

        _mToken.setCurrentIndex(_currentIndex = _EXP_SCALED_ONE);

        _smartMToken.setTotalNonEarningSupply(aliceBalance_);

        _smartMToken.setAccountOf(_alice, aliceBalance_);

        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        vm.expectRevert(UIntMath.InvalidUInt112.selector);
        _smartMToken.startEarningFor(_alice);
    }

    function test_startEarningFor() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setTotalNonEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000);

        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        vm.expectEmit();
        emit ISmartMToken.StartedEarning(_alice);

        _smartMToken.startEarningFor(_alice);

        assertEq(_smartMToken.isEarning(_alice), true);
        assertEq(_smartMToken.lastIndexOf(_alice), _currentIndex);
        assertEq(_smartMToken.balanceOf(_alice), 1000);

        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), 1_000);
    }

    function testFuzz_startEarningFor(uint240 balance_, uint128 index_) external {
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(_currentIndex)));
        index_ = uint128(bound(index_, _currentIndex, 10 * _EXP_SCALED_ONE));

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setTotalNonEarningSupply(balance_);

        _smartMToken.setAccountOf(_alice, balance_);

        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        _mToken.setCurrentIndex(index_);

        vm.expectEmit();
        emit ISmartMToken.StartedEarning(_alice);

        _smartMToken.startEarningFor(_alice);

        assertEq(_smartMToken.isEarning(_alice), true);
        assertEq(_smartMToken.lastIndexOf(_alice), index_);
        assertEq(_smartMToken.balanceOf(_alice), balance_);

        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), balance_);
    }

    /* ============ startEarningFor batch ============ */
    function test_startEarningFor_batch_earningIsDisabled() external {
        vm.expectRevert(ISmartMToken.EarningIsDisabled.selector);
        _smartMToken.startEarningFor(new address[](2));
    }

    function test_startEarningFor_batch_notApprovedEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        _smartMToken.enableEarning();

        address[] memory accounts_ = new address[](2);
        accounts_[0] = _alice;
        accounts_[1] = _bob;

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.NotApprovedEarner.selector, _bob));
        _smartMToken.startEarningFor(accounts_);
    }

    function test_startEarningFor_batch() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));
        _earnerManager.setEarnerDetails(_bob, true, 0, address(0));

        _smartMToken.enableEarning();

        address[] memory accounts_ = new address[](2);
        accounts_[0] = _alice;
        accounts_[1] = _bob;

        vm.expectEmit();
        emit ISmartMToken.StartedEarning(_alice);

        vm.expectEmit();
        emit ISmartMToken.StartedEarning(_bob);

        _smartMToken.startEarningFor(accounts_);
    }

    /* ============ stopEarningFor ============ */
    function test_stopEarningFor_isApprovedEarner() external {
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.IsApprovedEarner.selector, _alice));
        _smartMToken.stopEarningFor(_alice);
    }

    function test_stopEarningFor() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setPrincipalOfTotalEarningSupply(909);
        _smartMToken.setTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 999, _currentIndex, false, false);

        vm.expectEmit();
        emit ISmartMToken.StoppedEarning(_alice);

        _smartMToken.stopEarningFor(_alice);

        assertEq(_smartMToken.balanceOf(_alice), 999);
        assertEq(_smartMToken.isEarning(_alice), false);

        assertEq(_smartMToken.totalNonEarningSupply(), 999);
        assertEq(_smartMToken.totalEarningSupply(), 1);
    }

    function testFuzz_stopEarningFor(uint240 balance_, uint128 accountIndex_, uint128 index_) external {
        accountIndex_ = uint128(bound(index_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        balance_ = uint240(bound(balance_, 0, _getMaxAmount(accountIndex_)));
        index_ = uint128(bound(index_, accountIndex_, 10 * _EXP_SCALED_ONE));

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setTotalEarningSupply(balance_);

        _smartMToken.setAccountOf(_alice, balance_, accountIndex_, false, false);

        _mToken.setCurrentIndex(index_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        vm.expectEmit();
        emit ISmartMToken.StoppedEarning(_alice);

        _smartMToken.stopEarningFor(_alice);

        assertEq(_smartMToken.balanceOf(_alice), balance_ + accruedYield_);
        assertEq(_smartMToken.isEarning(_alice), false);

        assertEq(_smartMToken.totalNonEarningSupply(), balance_ + accruedYield_);
        assertEq(_smartMToken.totalEarningSupply(), 0);
    }

    /* ============ setClaimRecipient ============ */
    function test_setClaimRecipient() external {
        (, , , , bool hasClaimRecipient_) = _smartMToken.getAccountOf(_alice);

        assertFalse(hasClaimRecipient_);
        assertEq(_smartMToken.getInternalClaimRecipientOf(_alice), address(0));

        vm.prank(_alice);
        _smartMToken.setClaimRecipient(_alice);

        (, , , , hasClaimRecipient_) = _smartMToken.getAccountOf(_alice);

        assertTrue(hasClaimRecipient_);
        assertEq(_smartMToken.getInternalClaimRecipientOf(_alice), _alice);

        vm.prank(_alice);
        _smartMToken.setClaimRecipient(_bob);

        (, , , , hasClaimRecipient_) = _smartMToken.getAccountOf(_alice);

        assertTrue(hasClaimRecipient_);
        assertEq(_smartMToken.getInternalClaimRecipientOf(_alice), _bob);

        vm.prank(_alice);
        _smartMToken.setClaimRecipient(address(0));

        (, , , , hasClaimRecipient_) = _smartMToken.getAccountOf(_alice);

        assertFalse(hasClaimRecipient_);
        assertEq(_smartMToken.getInternalClaimRecipientOf(_alice), address(0));
    }

    /* ============ stopEarningFor batch ============ */
    function test_stopEarningFor_batch_isApprovedEarner() external {
        _earnerManager.setEarnerDetails(_bob, true, 0, address(0));

        address[] memory accounts_ = new address[](2);
        accounts_[0] = _alice;
        accounts_[1] = _bob;

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.IsApprovedEarner.selector, _bob));
        _smartMToken.stopEarningFor(accounts_);
    }

    function test_stopEarningFor_batch() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 0, _currentIndex, false, false);
        _smartMToken.setAccountOf(_bob, 0, _currentIndex, false, false);

        address[] memory accounts_ = new address[](2);
        accounts_[0] = _alice;
        accounts_[1] = _bob;

        vm.expectEmit();
        emit ISmartMToken.StoppedEarning(_alice);

        vm.expectEmit();
        emit ISmartMToken.StoppedEarning(_bob);

        _smartMToken.stopEarningFor(accounts_);
    }

    /* ============ enableEarning ============ */
    function test_enableEarning_notApprovedEarner() external {
        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.NotApprovedEarner.selector, address(_smartMToken)));
        _smartMToken.enableEarning();
    }

    function test_enableEarning_earningCannotBeReenabled() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), false);

        _smartMToken.disableEarning();

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        vm.expectRevert(ISmartMToken.EarningCannotBeReenabled.selector);
        _smartMToken.enableEarning();
    }

    function test_enableEarning() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        vm.expectEmit();
        emit ISmartMToken.EarningEnabled(_currentIndex);

        _smartMToken.enableEarning();
    }

    /* ============ disableEarning ============ */
    function test_disableEarning_earningIsDisabled() external {
        vm.expectRevert(ISmartMToken.EarningIsDisabled.selector);
        _smartMToken.disableEarning();

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), false);

        _smartMToken.disableEarning();

        vm.expectRevert(ISmartMToken.EarningIsDisabled.selector);
        _smartMToken.disableEarning();
    }

    function test_disableEarning_approvedEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.IsApprovedEarner.selector, address(_smartMToken)));
        _smartMToken.disableEarning();
    }

    function test_disableEarning() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), false);

        vm.expectEmit();
        emit ISmartMToken.EarningDisabled(_currentIndex);

        _smartMToken.disableEarning();
    }

    /* ============ balanceOf ============ */
    function test_balanceOf_nonEarner() external {
        _smartMToken.setAccountOf(_alice, 500);

        assertEq(_smartMToken.balanceOf(_alice), 500);

        _smartMToken.setAccountOf(_alice, 1_000);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
    }

    function test_balanceOf_earner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 500, _EXP_SCALED_ONE, false, false);

        assertEq(_smartMToken.balanceOf(_alice), 500);

        _smartMToken.setAccountOf(_alice, 1_000);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        _smartMToken.setLastIndexOf(_alice, 2 * _EXP_SCALED_ONE);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
    }

    /* ============ claimRecipientFor ============ */
    function test_claimRecipientFor_hasClaimRecipient() external {
        assertEq(_smartMToken.claimRecipientFor(_alice), address(0));

        _smartMToken.setAccountOf(_alice, 0, 0, false, true);
        _smartMToken.setInternalClaimRecipient(_alice, _bob);

        assertEq(_smartMToken.claimRecipientFor(_alice), _bob);
    }

    function test_claimRecipientFor_hasClaimOverrideRecipient() external {
        assertEq(_smartMToken.claimRecipientFor(_alice), address(0));

        _registrar.set(
            keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
            bytes32(uint256(uint160(_charlie)))
        );

        assertEq(_smartMToken.claimRecipientFor(_alice), _charlie);
    }

    function test_claimRecipientFor_hasClaimRecipientAndOverrideRecipient() external {
        assertEq(_smartMToken.claimRecipientFor(_alice), address(0));

        _smartMToken.setAccountOf(_alice, 0, 0, false, true);
        _smartMToken.setInternalClaimRecipient(_alice, _bob);

        _registrar.set(
            keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
            bytes32(uint256(uint160(_charlie)))
        );

        assertEq(_smartMToken.claimRecipientFor(_alice), _bob);
    }

    /* ============ totalSupply ============ */
    function test_totalSupply_onlyTotalNonEarningSupply() external {
        _smartMToken.setTotalNonEarningSupply(500);

        assertEq(_smartMToken.totalSupply(), 500);

        _smartMToken.setTotalNonEarningSupply(1_000);

        assertEq(_smartMToken.totalSupply(), 1_000);
    }

    function test_totalSupply_onlyTotalEarningSupply() external {
        _smartMToken.setTotalEarningSupply(500);

        assertEq(_smartMToken.totalSupply(), 500);

        _smartMToken.setTotalEarningSupply(1_000);

        assertEq(_smartMToken.totalSupply(), 1_000);
    }

    function test_totalSupply() external {
        _smartMToken.setTotalEarningSupply(400);

        _smartMToken.setTotalNonEarningSupply(600);

        assertEq(_smartMToken.totalSupply(), 1_000);

        _smartMToken.setTotalEarningSupply(700);

        assertEq(_smartMToken.totalSupply(), 1_300);

        _smartMToken.setTotalNonEarningSupply(1_000);

        assertEq(_smartMToken.totalSupply(), 1_700);
    }

    /* ============ currentIndex ============ */
    function test_currentIndex() external {
        assertEq(_smartMToken.currentIndex(), 0);

        _mToken.setCurrentIndex(2 * _EXP_SCALED_ONE);

        assertEq(_smartMToken.currentIndex(), 0);

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.enableEarning();

        assertEq(_smartMToken.currentIndex(), 2 * _EXP_SCALED_ONE);

        _mToken.setCurrentIndex(3 * _EXP_SCALED_ONE);

        assertEq(_smartMToken.currentIndex(), 3 * _EXP_SCALED_ONE);

        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), false);

        _smartMToken.disableEarning();

        assertEq(_smartMToken.currentIndex(), 3 * _EXP_SCALED_ONE);

        _mToken.setCurrentIndex(4 * _EXP_SCALED_ONE);

        assertEq(_smartMToken.currentIndex(), 3 * _EXP_SCALED_ONE);
    }

    /* ============ misc ============ */
    function testFuzz_wrap_transfer_unwrap(
        bool aliceIsEarning_,
        uint240 aliceWrap_,
        bool bobIsEarning_,
        uint240 bobWrap_,
        uint240 transfer_,
        uint128 index_
    ) external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));
        _earnerManager.setEarnerDetails(_bob, true, 0, address(0));

        _smartMToken.enableEarning();

        _mToken.setCurrentIndex(index_ = uint128(bound(index_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE)));

        aliceWrap_ = uint240(bound(aliceWrap_, 0, _getMaxAmount(index_) / 3));
        bobWrap_ = uint240(bound(bobWrap_, 0, _getMaxAmount(index_) / 3));

        _mToken.setBalanceOf(_alice, aliceWrap_);
        _mToken.setBalanceOf(_bob, bobWrap_);

        if (aliceIsEarning_) {
            _smartMToken.startEarningFor(_alice);
        }

        if (aliceWrap_ != 0) {
            vm.prank(_alice);
            _smartMToken.wrap(_alice, aliceWrap_);
        }

        _mToken.setCurrentIndex(index_ = uint128(bound(index_, index_, 10 * _EXP_SCALED_ONE)));

        if (bobIsEarning_) {
            _smartMToken.startEarningFor(_bob);
        }

        if (bobWrap_ != 0) {
            vm.prank(_bob);
            _smartMToken.wrap(_bob, bobWrap_);
        }

        _mToken.setCurrentIndex(index_ = uint128(bound(index_, index_, 10 * _EXP_SCALED_ONE)));

        uint240 aliceYield_ = _smartMToken.accruedYieldOf(_alice);
        uint240 bobYield_ = _smartMToken.accruedYieldOf(_bob);

        transfer_ = uint240(bound(transfer_, 0, _smartMToken.balanceWithYieldOf(_alice)));

        _mToken.setCurrentIndex(index_ = uint128(bound(index_, index_, 10 * _EXP_SCALED_ONE)));

        aliceYield_ += _smartMToken.accruedYieldOf(_alice);

        if (_smartMToken.balanceWithYieldOf(_alice) != 0) {
            vm.prank(_alice);
            _smartMToken.unwrap(_charlie);
        }

        _mToken.setCurrentIndex(index_ = uint128(bound(index_, index_, 10 * _EXP_SCALED_ONE)));

        bobYield_ += _smartMToken.accruedYieldOf(_bob);

        if (_smartMToken.balanceWithYieldOf(_bob) != 0) {
            vm.prank(_bob);
            _smartMToken.unwrap(_charlie);
        }

        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);

        uint240 total_ = aliceWrap_ + aliceYield_ + bobWrap_ + bobYield_;

        if (total_ < 100e6) {
            assertApproxEqAbs(_mToken.balanceOf(_charlie), total_, 100);
        } else {
            assertApproxEqRel(_mToken.balanceOf(_charlie), total_, 1e12);
        }
    }

    /* ============ utils ============ */
    function _getPrincipalAmountRoundedDown(uint240 presentAmount_, uint128 index_) internal pure returns (uint112) {
        return IndexingMath.divide240By128Down(presentAmount_, index_);
    }

    function _getPresentAmountRoundedDown(uint112 principalAmount_, uint128 index_) internal pure returns (uint240) {
        return IndexingMath.multiply112By128Down(principalAmount_, index_);
    }

    function _getMaxAmount(uint128 index_) internal pure returns (uint240 maxAmount_) {
        return (uint240(type(uint112).max) * index_) / _EXP_SCALED_ONE;
    }
}
