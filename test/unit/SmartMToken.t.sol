// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IndexingMath } from "../../lib/common/src/libs/IndexingMath.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { IERC20Extended } from "../../lib/common/src/interfaces/IERC20Extended.sol";

import { UIntMath } from "../../lib/common/src/libs/UIntMath.sol";
import { Proxy } from "../../lib/common/src/Proxy.sol";
import { Test } from "../../lib/forge-std/src/Test.sol";

import { ISmartMToken } from "../../src/interfaces/ISmartMToken.sol";

import { MockEarnerManager, MockM, MockRegistrar } from "../utils/Mocks.sol";
import { SmartMTokenHarness } from "../utils/SmartMTokenHarness.sol";

// TODO: Test for `totalAccruedYield()`.
// TODO: All operations involving earners should include demonstration of accrued yield being added to their balance.
// TODO: Add relevant unit tests while earning enabled/disabled.
// TODO: Replace all enableEarning with manually setting enable and disable indexes (and remove registrar add).

contract SmartMTokenTests is Test {
    uint56 internal constant _EXP_SCALED_ONE = IndexingMath.EXP_SCALED_ONE;
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

    uint128 internal _currentMIndex;

    MockEarnerManager internal _earnerManager;
    MockM internal _mToken;
    MockRegistrar internal _registrar;
    SmartMTokenHarness internal _implementation;
    SmartMTokenHarness internal _smartMToken;

    function setUp() external {
        _registrar = new MockRegistrar();

        _mToken = new MockM();

        _earnerManager = new MockEarnerManager();

        _implementation = new SmartMTokenHarness(
            address(_mToken),
            address(_registrar),
            address(_earnerManager),
            _excessDestination,
            _migrationAdmin
        );

        _smartMToken = SmartMTokenHarness(address(new Proxy(address(_implementation))));
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
        assertEq(_smartMToken.totalEarningPrincipal(), 0);
    }

    function test_internalWrap_toEarner_principalOverflows() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setAccountOf(_alice, 0, 0, false, false);

        uint240 amount_ = _getMaxAmount(1_100000000001);

        _mToken.setBalanceOf(_alice, amount_);

        vm.expectRevert(UIntMath.InvalidUInt112.selector);

        _smartMToken.internalWrap(_alice, _alice, amount_);
    }

    function test_internalWrap_toEarner_smallAmounts() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(955);

        _smartMToken.setAccountOf(_alice, 1_000, 955, false, false); // 1_050 balance with yield.

        _mToken.setBalanceOf(_alice, 1_002);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 999);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 999), 999);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 955 + 908);
        assertEq(_smartMToken.balanceOf(_alice), 1_000 + 999);
        assertEq(_smartMToken.accruedYieldOf(_alice), 50);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 955 + 908);
        assertEq(_smartMToken.totalEarningSupply(), 1_000 + 999);
        assertEq(_smartMToken.totalAccruedYield(), 50);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 1), 1);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 955 + 908 + 0);
        assertEq(_smartMToken.balanceOf(_alice), 1_000 + 999 + 1);
        assertEq(_smartMToken.accruedYieldOf(_alice), 49);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 955 + 908 + 0);
        assertEq(_smartMToken.totalEarningSupply(), 1_000 + 999 + 1);
        assertEq(_smartMToken.totalAccruedYield(), 49);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 2);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 2), 2);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 955 + 908 + 0 + 1);
        assertEq(_smartMToken.balanceOf(_alice), 1_000 + 999 + 1 + 2);
        assertEq(_smartMToken.accruedYieldOf(_alice), 48);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 955 + 908 + 0 + 1);
        assertEq(_smartMToken.totalEarningSupply(), 1_000 + 999 + 1 + 2);
        assertEq(_smartMToken.totalAccruedYield(), 48);
    }

    function test_internalWrap_toEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000_000e6);
        _smartMToken.setPrincipalOfTotalEarningSupply(955_000e6);

        _smartMToken.setAccountOf(_alice, 1_000_000e6, 955_000e6, false, false); // 1_050_500e6 balance with yield.

        _mToken.setBalanceOf(_alice, 1_000_000e6);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 1_000_000e6);

        assertEq(_smartMToken.internalWrap(_alice, _alice, 1_000_000e6), 1_000_000e6);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 955_000e6 + 909_090_909090);
        assertEq(_smartMToken.balanceOf(_alice), 1_000_000e6 + 1_000_000e6);
        assertEq(_smartMToken.accruedYieldOf(_alice), 50499_999999);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 955_000e6 + 909_090_909090);
        assertEq(_smartMToken.totalEarningSupply(), 1_000_000e6 + 1_000_000e6);
        assertEq(_smartMToken.totalAccruedYield(), 50499_999999);
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
        uint240 balanceWithYield_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, accountEarning_, balanceWithYield_, balance_);

        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(_smartMToken.currentIndex()) - balanceWithYield_));

        _mToken.setBalanceOf(_alice, wrapAmount_);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrap(_alice, wrapAmount_);

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + wrapAmount_);

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
        uint240 balanceWithYield_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, accountEarning_, balanceWithYield_, balance_);

        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(_smartMToken.currentIndex()) - balanceWithYield_));

        _mToken.setBalanceOf(_alice, wrapAmount_);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrap(_alice);

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + wrapAmount_);

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
        uint240 balanceWithYield_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, accountEarning_, balanceWithYield_, balance_);

        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(_smartMToken.currentIndex()) - balanceWithYield_));

        _mToken.setBalanceOf(_alice, wrapAmount_);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrapWithPermit(_alice, wrapAmount_, 0, 0, bytes32(0), bytes32(0));

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + wrapAmount_);

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
        uint240 balanceWithYield_,
        uint240 balance_,
        uint240 wrapAmount_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, accountEarning_, balanceWithYield_, balance_);

        wrapAmount_ = uint240(bound(wrapAmount_, 0, _getMaxAmount(_smartMToken.currentIndex()) - balanceWithYield_));

        _mToken.setBalanceOf(_alice, wrapAmount_);

        if (wrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), _alice, wrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.wrapWithPermit(_alice, wrapAmount_, 0, hex"");

        if (wrapAmount_ == 0) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ + wrapAmount_);

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

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();

        _smartMToken.setAccountOf(_alice, 999, 999, false, false);

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
        assertEq(_smartMToken.totalEarningPrincipal(), 0);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 500);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 500), 500);

        assertEq(_smartMToken.balanceOf(_alice), 0);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 0);
    }

    function test_internalUnwrap_fromEarner_smallAmounts() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(955);

        _smartMToken.setAccountOf(_alice, 1_000, 955, false, false); // 1_050 balance with yield.

        _mToken.setBalanceOf(address(_smartMToken), 1_050);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 1);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 1), 0);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 955 - 1);
        assertEq(_smartMToken.balanceOf(_alice), 1_000 - 1);
        assertEq(_smartMToken.accruedYieldOf(_alice), 50);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 955 - 1);
        assertEq(_smartMToken.totalEarningSupply(), 1_000 - 1);
        assertEq(_smartMToken.totalAccruedYield(), 50);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 999);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 999), 998);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 955 - 1 - 909);
        assertEq(_smartMToken.balanceOf(_alice), 1_000 - 1 - 999);
        assertEq(_smartMToken.accruedYieldOf(_alice), 49);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 955 - 1 - 909);
        assertEq(_smartMToken.totalEarningSupply(), 1_000 - 1 - 999);
        assertEq(_smartMToken.totalAccruedYield(), 49);
    }

    function test_internalUnwrap_fromEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000_000e6);
        _smartMToken.setPrincipalOfTotalEarningSupply(955_000e6);

        _smartMToken.setAccountOf(_alice, 1_000_000e6, 955_000e6, false, false); // 1_050_500e6 balance with yield.

        _mToken.setBalanceOf(address(_smartMToken), 1_050_500e6);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, address(0), 1_000_000e6);

        assertEq(_smartMToken.internalUnwrap(_alice, _alice, 1_000_000e6), 999_999_999999);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 955_000e6 - 909_090_909090 - 1);
        assertEq(_smartMToken.balanceOf(_alice), 1_000_000e6 - 1_000_000e6);
        assertEq(_smartMToken.accruedYieldOf(_alice), 50499_999999);
        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 955_000e6 - 909_090_909090 - 1);
        assertEq(_smartMToken.totalEarningSupply(), 1_000_000e6 - 1_000_000e6);
        assertEq(_smartMToken.totalAccruedYield(), 50499_999999);
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
        uint240 balanceWithYield_,
        uint240 balance_,
        uint240 unwrapAmount_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, accountEarning_, balanceWithYield_, balance_);

        uint240 maxAmount_ = _getMaxAmount(_smartMToken.currentIndex());
        maxAmount_ = maxAmount_ > 2 * balance_ ? 2 * balance_ : maxAmount_;
        unwrapAmount_ = uint240(bound(unwrapAmount_, 0, maxAmount_));

        _mToken.setBalanceOf(address(_smartMToken), balanceWithYield_);

        if (unwrapAmount_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else if (unwrapAmount_ > balance_) {
            vm.expectRevert(
                abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, balance_, unwrapAmount_)
            );
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, address(0), unwrapAmount_);
        }

        vm.startPrank(_alice);
        _smartMToken.unwrap(_alice, unwrapAmount_);

        if ((unwrapAmount_ == 0) || (unwrapAmount_ > balance_)) return;

        assertEq(_smartMToken.balanceOf(_alice), balance_ - unwrapAmount_);

        assertEq(
            accountEarning_ ? _smartMToken.totalEarningSupply() : _smartMToken.totalNonEarningSupply(),
            _smartMToken.balanceOf(_alice)
        );
    }

    /* ============ unwrap entire balance ============ */
    function testFuzz_unwrap_entireBalance(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balanceWithYield_,
        uint240 balance_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, accountEarning_, balanceWithYield_, balance_);

        _mToken.setBalanceOf(address(_smartMToken), balanceWithYield_);

        if (balance_ == 0) {
            vm.expectRevert(abi.encodeWithSelector(IERC20Extended.InsufficientAmount.selector, (0)));
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, address(0), balance_);
        }

        vm.startPrank(_alice);
        _smartMToken.unwrap(_alice);

        if (balance_ == 0) return;

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

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, false, false); // 1_100 balance with yield.

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        vm.expectEmit();
        emit ISmartMToken.Claimed(_alice, _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 100);

        assertEq(_smartMToken.claimFor(_alice), 100);

        assertEq(_smartMToken.balanceOf(_alice), 1_100);
        assertEq(_smartMToken.earningPrincipalOf(_alice), 1_000);

        assertEq(_smartMToken.totalEarningSupply(), 1_100);
        assertEq(_smartMToken.totalEarningPrincipal(), 1_000);
    }

    function test_claimFor_earner_withOverrideRecipient() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _registrar.set(
            keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
            bytes32(uint256(uint160(_bob)))
        );

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, false, false); // 1_100 balance with yield.

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        vm.expectEmit();
        emit ISmartMToken.Claimed(_alice, _bob, 100);

        vm.expectEmit();
        emit IERC20.Transfer(address(0), _alice, 100);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 100);

        assertEq(_smartMToken.claimFor(_alice), 100);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.earningPrincipalOf(_alice), 909);
        assertEq(_smartMToken.balanceOf(_bob), 100);

        assertEq(_smartMToken.totalEarningSupply(), 1_000);
        assertEq(_smartMToken.totalNonEarningSupply(), 100);
        assertEq(_smartMToken.totalEarningPrincipal(), 909);
    }

    function test_claimFor_earner_withFee() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, true, false); // 1_100 balance with yield.

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
        assertEq(_smartMToken.earningPrincipalOf(_alice), 986);
        assertEq(_smartMToken.balanceOf(_bob), 15);

        assertEq(_smartMToken.totalEarningSupply(), 1_085);
        assertEq(_smartMToken.totalNonEarningSupply(), 15);
        assertEq(_smartMToken.totalEarningPrincipal(), 986);
    }

    function test_claimFor_earner_withFeeAboveOneHundredPercent() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, true, false); // 1_100 balance with yield.

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
        assertEq(_smartMToken.earningPrincipalOf(_alice), 909);
        assertEq(_smartMToken.balanceOf(_bob), 100);

        assertEq(_smartMToken.totalEarningSupply(), 1_000);
        assertEq(_smartMToken.totalNonEarningSupply(), 100);
        assertEq(_smartMToken.totalEarningPrincipal(), 909);
    }

    function test_claimFor_earner_withOverrideRecipientAndFee() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _registrar.set(
            keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
            bytes32(uint256(uint160(_charlie)))
        );

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, true, false); // 1_100 balance with yield.

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
        assertEq(_smartMToken.earningPrincipalOf(_alice), 908);
        assertEq(_smartMToken.balanceOf(_bob), 15);
        assertEq(_smartMToken.balanceOf(_charlie), 85);

        assertEq(_smartMToken.totalEarningSupply(), 1_000);
        assertEq(_smartMToken.totalNonEarningSupply(), 100);
        assertEq(_smartMToken.totalEarningPrincipal(), 908);
    }

    function testFuzz_claimFor(
        bool earningEnabled_,
        bool accountEarning_,
        uint240 balanceWithYield_,
        uint240 balance_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_,
        bool claimOverride_,
        uint16 feeRate_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, accountEarning_, balanceWithYield_, balance_);

        if (claimOverride_) {
            _registrar.set(
                keccak256(abi.encode(_CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, _alice)),
                bytes32(uint256(uint160(_charlie)))
            );
        }

        if (feeRate_ != 0) {
            _smartMToken.setHasEarnerDetails(_alice, true);
            _earnerManager.setEarnerDetails(_alice, true, feeRate_, _bob);
        }

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

    /* ============ excess ============ */
    function test_excess() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        assertEq(_smartMToken.excess(), 0);

        _smartMToken.setTotalNonEarningSupply(1_000);
        _smartMToken.setTotalEarningSupply(1_000);
        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);

        _mToken.setBalanceOf(address(_smartMToken), 2_100);

        assertEq(_smartMToken.excess(), 0);

        _mToken.setBalanceOf(address(_smartMToken), 2_101);

        assertEq(_smartMToken.excess(), 0);

        _mToken.setBalanceOf(address(_smartMToken), 2_102);

        assertEq(_smartMToken.excess(), 1);

        _mToken.setBalanceOf(address(_smartMToken), 3_102);

        assertEq(_smartMToken.excess(), 1_001);

        _mToken.setCurrentIndex(_currentMIndex = 1_331000000000);

        assertEq(_smartMToken.excess(), 891);
    }

    /* ============ claimExcess ============ */
    function testFuzz_claimExcess(
        bool earningEnabled_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_,
        uint240 totalNonEarningSupply_,
        uint112 projectedTotalEarningSupply_,
        uint240 mBalance_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        uint128 currentIndex_ = _smartMToken.currentIndex();
        uint240 maxAmount_ = _getMaxAmount(currentIndex_);

        totalNonEarningSupply_ = uint240(bound(totalNonEarningSupply_, 0, maxAmount_));

        projectedTotalEarningSupply_ = uint112(
            bound(projectedTotalEarningSupply_, 0, maxAmount_ - totalNonEarningSupply_)
        );

        uint112 totalEarningPrincipal_ = IndexingMath.getPrincipalAmountRoundedDown(
            projectedTotalEarningSupply_,
            currentIndex_
        );

        mBalance_ = uint240(bound(mBalance_, totalNonEarningSupply_, type(uint240).max));

        _mToken.setBalanceOf(address(_smartMToken), mBalance_);
        _smartMToken.setTotalNonEarningSupply(totalNonEarningSupply_);
        _smartMToken.setPrincipalOfTotalEarningSupply(totalEarningPrincipal_);

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

    function test_transfer_insufficientBalance_toSelf() external {
        _smartMToken.setAccountOf(_alice, 999);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, 999, 1_000));
        vm.prank(_alice);
        _smartMToken.transfer(_alice, 1_000);
    }

    function test_transfer_insufficientBalance_fromNonEarner_toNonEarner() external {
        _smartMToken.setAccountOf(_alice, 999);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, 999, 1_000));
        vm.prank(_alice);
        _smartMToken.transfer(_bob, 1_000);
    }

    function test_transfer_insufficientBalance_fromEarner_toNonEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setAccountOf(_alice, 999, 999, false, false);

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
        assertEq(_smartMToken.totalEarningPrincipal(), 0);
    }

    function testFuzz_transfer_fromNonEarner_toNonEarner(
        uint256 supply_,
        uint256 aliceBalance_,
        uint256 transferAmount_
    ) external {
        supply_ = bound(supply_, 1, type(uint240).max);
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
        assertEq(_smartMToken.totalEarningPrincipal(), 0);
    }

    function test_transfer_fromEarner_toNonEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);
        _smartMToken.setTotalEarningSupply(1_000);

        _smartMToken.setTotalNonEarningSupply(500);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, false, false); // 1_100 balance with yield.

        _smartMToken.setAccountOf(_bob, 500);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 100);

        assertEq(_smartMToken.balanceOf(_bob), 500);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 500);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 545);
        assertEq(_smartMToken.balanceOf(_alice), 500);
        assertEq(_smartMToken.accruedYieldOf(_alice), 99);

        assertEq(_smartMToken.balanceOf(_bob), 1_000);

        assertEq(_smartMToken.totalNonEarningSupply(), 1_000);
        assertEq(_smartMToken.totalEarningPrincipal(), 545);
        assertEq(_smartMToken.totalEarningSupply(), 500);
        assertEq(_smartMToken.totalAccruedYield(), 99);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 1);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 1);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 544);
        assertEq(_smartMToken.balanceOf(_alice), 499);
        assertEq(_smartMToken.accruedYieldOf(_alice), 99);

        assertEq(_smartMToken.balanceOf(_bob), 1_001);

        assertEq(_smartMToken.totalNonEarningSupply(), 1_001);
        assertEq(_smartMToken.totalEarningPrincipal(), 544);
        assertEq(_smartMToken.totalEarningSupply(), 499);
        assertEq(_smartMToken.totalAccruedYield(), 99);
    }

    function test_transfer_fromNonEarner_toEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setPrincipalOfTotalEarningSupply(500);
        _smartMToken.setTotalEarningSupply(500);

        _smartMToken.setTotalNonEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000);

        _smartMToken.setAccountOf(_bob, 500, 500, false, false); // 550 balance with yield.

        assertEq(_smartMToken.balanceOf(_alice), 1_000);

        assertEq(_smartMToken.balanceOf(_bob), 500);
        assertEq(_smartMToken.accruedYieldOf(_bob), 50);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 500);

        assertEq(_smartMToken.balanceOf(_alice), 500);

        assertEq(_smartMToken.earningPrincipalOf(_bob), 954);
        assertEq(_smartMToken.balanceOf(_bob), 1_000);
        assertEq(_smartMToken.accruedYieldOf(_bob), 49);

        assertEq(_smartMToken.totalNonEarningSupply(), 500);
        assertEq(_smartMToken.totalEarningPrincipal(), 954);
        assertEq(_smartMToken.totalEarningSupply(), 1_000);
        assertEq(_smartMToken.totalAccruedYield(), 49);
    }

    function test_transfer_fromEarner_toEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setPrincipalOfTotalEarningSupply(1_500);
        _smartMToken.setTotalEarningSupply(1_500);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, false, false); // 1_100 balance with yield.
        _smartMToken.setAccountOf(_bob, 500, 500, false, false); // 550 balance with yield.

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 100);

        assertEq(_smartMToken.balanceOf(_bob), 500);
        assertEq(_smartMToken.accruedYieldOf(_bob), 50);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _bob, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_bob, 500);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 545);
        assertEq(_smartMToken.balanceOf(_alice), 500);
        assertEq(_smartMToken.accruedYieldOf(_alice), 99);

        assertEq(_smartMToken.earningPrincipalOf(_bob), 954);
        assertEq(_smartMToken.balanceOf(_bob), 1_000);
        assertEq(_smartMToken.accruedYieldOf(_bob), 49);

        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 1499);
        assertEq(_smartMToken.totalEarningSupply(), 1_500);
        assertEq(_smartMToken.totalAccruedYield(), 148);
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
        assertEq(_smartMToken.totalEarningPrincipal(), 0);
    }

    function test_transfer_earnerToSelf() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);
        _smartMToken.setTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, false, false); // 1_100 balance with yield.

        _mToken.setCurrentIndex(1_331000000000);

        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 210);

        vm.expectEmit();
        emit IERC20.Transfer(_alice, _alice, 500);

        vm.prank(_alice);
        _smartMToken.transfer(_alice, 500);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 1_000);
        assertEq(_smartMToken.balanceOf(_alice), 1_000);
        assertEq(_smartMToken.accruedYieldOf(_alice), 210);

        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 1_000);
        assertEq(_smartMToken.totalEarningSupply(), 1_000);
        assertEq(_smartMToken.totalAccruedYield(), 210);
    }

    function testFuzz_transfer(
        bool earningEnabled_,
        bool aliceEarning_,
        bool bobEarning_,
        uint240 aliceBalanceWithYield_,
        uint240 aliceBalance_,
        uint240 bobBalanceWithYield_,
        uint240 bobBalance_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_,
        uint240 amount_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (aliceBalanceWithYield_, aliceBalance_) = _getFuzzedBalances(aliceBalanceWithYield_, aliceBalance_);

        _setupAccount(_alice, aliceEarning_, aliceBalanceWithYield_, aliceBalance_);

        (bobBalanceWithYield_, bobBalance_) = _getFuzzedBalances(
            bobBalanceWithYield_,
            bobBalance_,
            _getMaxAmount(_smartMToken.currentIndex()) - aliceBalanceWithYield_
        );

        _setupAccount(_bob, bobEarning_, bobBalanceWithYield_, bobBalance_);

        amount_ = uint240(bound(amount_, 0, aliceBalance_));

        if (amount_ > aliceBalance_) {
            vm.expectRevert(
                abi.encodeWithSelector(ISmartMToken.InsufficientBalance.selector, _alice, aliceBalance_, amount_)
            );
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(_alice, _bob, amount_);
        }

        vm.prank(_alice);
        _smartMToken.transfer(_bob, amount_);

        if (amount_ > aliceBalance_) return;

        assertEq(_smartMToken.balanceOf(_alice), aliceBalance_ - amount_);
        assertEq(_smartMToken.balanceOf(_bob), bobBalance_ + amount_);

        if (aliceEarning_ && bobEarning_) {
            assertEq(_smartMToken.totalEarningSupply(), aliceBalance_ + bobBalance_);
        } else if (aliceEarning_) {
            assertEq(_smartMToken.totalEarningSupply(), aliceBalance_ - amount_);
            assertEq(_smartMToken.totalNonEarningSupply(), bobBalance_ + amount_);
        } else if (bobEarning_) {
            assertEq(_smartMToken.totalNonEarningSupply(), aliceBalance_ - amount_);
            assertEq(_smartMToken.totalEarningSupply(), bobBalance_ + amount_);
        } else {
            assertEq(_smartMToken.totalNonEarningSupply(), aliceBalance_ + bobBalance_);
        }
    }

    /* ============ startEarningFor ============ */
    function test_startEarningFor_notApprovedEarner() external {
        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.NotApprovedEarner.selector, _alice));
        _smartMToken.startEarningFor(_alice);
    }

    function test_startEarning_overflow() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        uint256 aliceBalance_ = _getMaxAmount(1_100000000000) + 2;

        _smartMToken.setTotalNonEarningSupply(aliceBalance_);

        _smartMToken.setAccountOf(_alice, aliceBalance_);

        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        vm.expectRevert(UIntMath.InvalidUInt112.selector);
        _smartMToken.startEarningFor(_alice);
    }

    function test_startEarningFor() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setTotalNonEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000);

        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        vm.expectEmit();
        emit ISmartMToken.StartedEarning(_alice);

        _smartMToken.startEarningFor(_alice);

        assertEq(_smartMToken.isEarning(_alice), true);
        assertEq(_smartMToken.earningPrincipalOf(_alice), 909);
        assertEq(_smartMToken.balanceOf(_alice), 1000);

        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 909);
    }

    function testFuzz_startEarningFor(
        bool earningEnabled_,
        uint240 balance_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        uint128 currentIndex_ = _smartMToken.currentIndex();

        balance_ = uint240(bound(balance_, 0, _getMaxAmount(currentIndex_)));

        _smartMToken.setTotalNonEarningSupply(balance_);

        _smartMToken.setAccountOf(_alice, balance_);

        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        vm.expectEmit();
        emit ISmartMToken.StartedEarning(_alice);

        _smartMToken.startEarningFor(_alice);

        uint112 earningPrincipal_ = IndexingMath.getPrincipalAmountRoundedDown(balance_, currentIndex_);

        assertEq(_smartMToken.isEarning(_alice), true);
        assertEq(_smartMToken.earningPrincipalOf(_alice), earningPrincipal_);
        assertEq(_smartMToken.balanceOf(_alice), balance_);

        assertEq(_smartMToken.totalNonEarningSupply(), 0);
        assertEq(_smartMToken.totalEarningSupply(), balance_);
        assertEq(_smartMToken.totalEarningPrincipal(), earningPrincipal_);
    }

    /* ============ startEarningFor batch ============ */
    function test_startEarningFor_batch_notApprovedEarner() external {
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));

        address[] memory accounts_ = new address[](2);
        accounts_[0] = _alice;
        accounts_[1] = _bob;

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.NotApprovedEarner.selector, _bob));
        _smartMToken.startEarningFor(accounts_);
    }

    function test_startEarningFor_batch() external {
        _earnerManager.setEarnerDetails(_alice, true, 0, address(0));
        _earnerManager.setEarnerDetails(_bob, true, 0, address(0));

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

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setPrincipalOfTotalEarningSupply(1_000);
        _smartMToken.setTotalEarningSupply(1_000);

        _smartMToken.setAccountOf(_alice, 1_000, 1_000, false, false); // 1_100 balance with yield.

        vm.expectEmit();
        emit ISmartMToken.StoppedEarning(_alice);

        _smartMToken.stopEarningFor(_alice);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 0);
        assertEq(_smartMToken.balanceOf(_alice), 1_100);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);
        assertEq(_smartMToken.isEarning(_alice), false);

        assertEq(_smartMToken.totalNonEarningSupply(), 1_100);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 0);
    }

    function testFuzz_stopEarningFor(
        bool earningEnabled_,
        uint240 balanceWithYield_,
        uint240 balance_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) external {
        (currentMIndex_, enableMIndex_, disableIndex_) = _getFuzzedIndices(
            currentMIndex_,
            enableMIndex_,
            disableIndex_
        );

        _setupIndexes(earningEnabled_, currentMIndex_, enableMIndex_, disableIndex_);

        (balanceWithYield_, balance_) = _getFuzzedBalances(balanceWithYield_, balance_);

        _setupAccount(_alice, true, balanceWithYield_, balance_);

        uint240 accruedYield_ = _smartMToken.accruedYieldOf(_alice);

        vm.expectEmit();
        emit ISmartMToken.StoppedEarning(_alice);

        _smartMToken.stopEarningFor(_alice);

        assertEq(_smartMToken.earningPrincipalOf(_alice), 0);
        assertEq(_smartMToken.balanceOf(_alice), balance_ + accruedYield_);
        assertEq(_smartMToken.accruedYieldOf(_alice), 0);
        assertEq(_smartMToken.isEarning(_alice), false);

        assertEq(_smartMToken.totalNonEarningSupply(), balance_ + accruedYield_);
        assertEq(_smartMToken.totalEarningSupply(), 0);
        assertEq(_smartMToken.totalAccruedYield(), 0);
        assertEq(_smartMToken.totalEarningPrincipal(), 0);
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
        _smartMToken.setAccountOf(_alice, 0, 0, false, false);
        _smartMToken.setAccountOf(_bob, 0, 0, false, false);

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

    function test_enableEarning_firstTime() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);

        vm.expectEmit();
        emit ISmartMToken.EarningEnabled(_currentMIndex);

        _smartMToken.enableEarning();

        assertEq(_smartMToken.disableIndex(), 0);
        assertEq(_smartMToken.enableMIndex(), _currentMIndex);
        assertEq(_smartMToken.currentIndex(), _EXP_SCALED_ONE);
    }

    function test_enableEarning() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        _smartMToken.setDisableIndex(1_100000000000);

        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        vm.expectEmit();
        emit ISmartMToken.EarningEnabled(_currentMIndex);

        _smartMToken.enableEarning();

        assertEq(_smartMToken.disableIndex(), 1_100000000000);
        assertEq(_smartMToken.enableMIndex(), _currentMIndex);
        assertEq(_smartMToken.currentIndex(), 1_100000000000); // 1.21 / 1.10
    }

    /* ============ disableEarning ============ */
    function test_disableEarning_earningIsDisabled() external {
        vm.expectRevert(ISmartMToken.EarningIsDisabled.selector);
        _smartMToken.disableEarning();
    }

    function test_disableEarning_approvedEarner() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);

        vm.expectRevert(abi.encodeWithSelector(ISmartMToken.IsApprovedEarner.selector, address(_smartMToken)));
        _smartMToken.disableEarning();
    }

    function test_disableEarning() external {
        _smartMToken.setDisableIndex(1_100000000000);
        _smartMToken.setEnableMIndex(1_210000000000);

        _mToken.setCurrentIndex(_currentMIndex = 1_331000000000);

        vm.expectEmit();
        emit ISmartMToken.EarningDisabled(1_210000000000); // (1.10 * 1.331) / 1.21

        _smartMToken.disableEarning();

        assertEq(_smartMToken.disableIndex(), 1_210000000000);
        assertEq(_smartMToken.enableMIndex(), 0);
        assertEq(_smartMToken.currentIndex(), 1_210000000000);
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

        _mToken.setCurrentIndex(_currentMIndex = 1_100000000000);
        _smartMToken.enableEarning();
        _mToken.setCurrentIndex(_currentMIndex = 1_210000000000);

        _smartMToken.setAccountOf(_alice, 500, 500, false, false);

        assertEq(_smartMToken.balanceOf(_alice), 500);

        _smartMToken.setEarningPrincipalOf(_alice, 1_000);

        assertEq(_smartMToken.balanceOf(_alice), 500);

        _smartMToken.setAccountOf(_alice, 1_000);

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
        assertEq(_smartMToken.currentIndex(), _EXP_SCALED_ONE);

        _mToken.setCurrentIndex(1_331000000000);

        assertEq(_smartMToken.currentIndex(), _EXP_SCALED_ONE);

        _smartMToken.setDisableIndex(1_050000000000);

        assertEq(_smartMToken.currentIndex(), 1_050000000000);

        _smartMToken.setDisableIndex(1_100000000000);

        assertEq(_smartMToken.currentIndex(), 1_100000000000);

        _smartMToken.setEnableMIndex(1_100000000000);

        assertEq(_smartMToken.currentIndex(), 1_331000000000);

        _smartMToken.setEnableMIndex(1_155000000000);

        assertEq(_smartMToken.currentIndex(), 1_267619047619);

        _smartMToken.setEnableMIndex(1_210000000000);

        assertEq(_smartMToken.currentIndex(), 1_210000000000);

        _smartMToken.setEnableMIndex(1_270500000000);

        assertEq(_smartMToken.currentIndex(), 1_152380952380);

        _smartMToken.setEnableMIndex(1_331000000000);

        assertEq(_smartMToken.currentIndex(), 1_100000000000);

        _mToken.setCurrentIndex(1_464100000000);

        assertEq(_smartMToken.currentIndex(), 1_210000000000);
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

    function _getFuzzedIndices(
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) internal pure returns (uint128, uint128, uint128) {
        currentMIndex_ = uint128(bound(currentMIndex_, _EXP_SCALED_ONE, 10 * _EXP_SCALED_ONE));
        enableMIndex_ = uint128(bound(enableMIndex_, _EXP_SCALED_ONE, currentMIndex_));

        disableIndex_ = uint128(
            bound(disableIndex_, _EXP_SCALED_ONE, (currentMIndex_ * _EXP_SCALED_ONE) / enableMIndex_)
        );

        return (currentMIndex_, enableMIndex_, disableIndex_);
    }

    function _setupIndexes(
        bool earningEnabled_,
        uint128 currentMIndex_,
        uint128 enableMIndex_,
        uint128 disableIndex_
    ) internal {
        _mToken.setCurrentIndex(currentMIndex_);
        _smartMToken.setDisableIndex(disableIndex_);

        if (earningEnabled_) {
            _registrar.setListContains(_EARNERS_LIST_NAME, address(_smartMToken), true);
            _smartMToken.setEnableMIndex(enableMIndex_);
        }
    }

    function _getFuzzedBalances(uint240 balanceWithYield_, uint240 balance_) internal view returns (uint240, uint240) {
        uint128 currentIndex_ = _smartMToken.currentIndex();

        balanceWithYield_ = uint240(bound(balanceWithYield_, 0, _getMaxAmount(currentIndex_)));
        balance_ = uint240(bound(balance_, (balanceWithYield_ * _EXP_SCALED_ONE) / currentIndex_, balanceWithYield_));

        return (balanceWithYield_, balance_);
    }

    function _getFuzzedBalances(
        uint240 balanceWithYield_,
        uint240 balance_,
        uint240 maxAmount_
    ) internal view returns (uint240, uint240) {
        uint128 currentIndex_ = _smartMToken.currentIndex();

        balanceWithYield_ = uint240(bound(balanceWithYield_, 0, maxAmount_));
        balance_ = uint240(bound(balance_, (balanceWithYield_ * _EXP_SCALED_ONE) / currentIndex_, balanceWithYield_));

        return (balanceWithYield_, balance_);
    }

    function _setupAccount(
        address account_,
        bool accountEarning_,
        uint240 balanceWithYield_,
        uint240 balance_
    ) internal {
        if (accountEarning_) {
            uint112 principal_ = IndexingMath.getPrincipalAmountRoundedDown(
                balanceWithYield_,
                _smartMToken.currentIndex()
            );

            _smartMToken.setAccountOf(account_, balance_, principal_, false, false);
            _smartMToken.setTotalEarningSupply(_smartMToken.totalEarningSupply() + balance_);
            _smartMToken.setPrincipalOfTotalEarningSupply(_smartMToken.totalEarningPrincipal() + principal_);
        } else {
            _smartMToken.setAccountOf(account_, balance_);
            _smartMToken.setTotalNonEarningSupply(_smartMToken.totalNonEarningSupply() + balance_);
        }
    }
}
