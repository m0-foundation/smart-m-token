// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { MorphoTestBase } from "./vendor/morpho-blue/MorphoTestBase.sol";

contract MorphoBlueTests is MorphoTestBase {
    uint256 internal _wrapperBalanceOfM;

    uint256 internal _morphoBalanceOfUSDC;
    uint256 internal _aliceBalanceOfUSDC;
    uint256 internal _bobBalanceOfUSDC;
    uint256 internal _carolBalanceOfUSDC;
    uint256 internal _daveBalanceOfUSDC;

    uint256 internal _morphoBalanceOfWM;
    uint256 internal _aliceBalanceOfWM;
    uint256 internal _bobBalanceOfWM;
    uint256 internal _carolBalanceOfWM;
    uint256 internal _daveBalanceOfWM;

    uint256 internal _morphoAccruedYield;

    uint240 internal _excess;

    function setUp() external {
        _oracle = _createOracle();

        _wrapperBalanceOfM = _mToken.balanceOf(address(_wrappedMToken));

        _morphoBalanceOfUSDC = IERC20(_USDC).balanceOf(_MORPHO);
        _morphoBalanceOfWM = _wrappedMToken.balanceOf(_MORPHO);

        _excess = _wrappedMToken.excess();

        _deployV2Components();
        _migrate();
    }

    function test_state() external view {
        assertTrue(_mToken.isEarning(address(_wrappedMToken)));
        assertTrue(_wrappedMToken.isEarningEnabled());
        assertFalse(_wrappedMToken.isEarning(_MORPHO));
    }

    function test_morphoBlue_nonEarning_wM_as_collateralToken() external {
        /* ============ Alice Creates Market ============ */

        _giveWM(_alice, 1_000_100e6);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM += 1_000_100e6);

        _give(_USDC, _alice, 1_000_100e6);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC += 1_000_100e6);

        // NOTE: Creating a market also result in `_alice` supplying 1.00 USDC as supply, 1.00 wM as collateral, and
        //       borrowing 0.90 USDC.
        _createMarket(_alice, _USDC);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM -= 1e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 1e6);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC -= 100000);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 100000);

        /* ============ Alice Supplies Seed USDC For Loans ============ */

        _supply(_alice, _USDC, 1_000_000e6, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC -= 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 1_000_000e6);

        /* ============ Bob Takes Out USDC Loan Against wM Collateral ============ */

        _giveWM(_bob, 1_000_100e6);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM += 1_000_100e6);

        _supplyCollateral(_bob, address(_wrappedMToken), 1_000_000e6, _USDC);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM -= 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 1_000_000e6);

        _borrow(_bob, _USDC, 900_000e6, _bob, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC += 900_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC -= 900_000e6);

        /* ============ First 1-Year Time Warp ============ */

        // Move 1 year forward and check that no yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 383_154_367021);

        // `startEarningFor` hasn't been called so no wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 383_154_367021);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);

        /* ============ Bob Repays USDC Loan And Withdraws wM Collateral ============ */

        _repay(_bob, _USDC, 900_000e6, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC -= 900_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 900_000e6);

        _withdrawCollateral(_bob, address(_wrappedMToken), 1_000_000e6, _bob, _USDC);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM += 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM -= 1_000_000e6);

        /* ============ Alice Withdraws Seed USDC For Loans ============ */

        _withdraw(_alice, _USDC, 1_000_000e6, _alice, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC += 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC -= 1_000_000e6);

        /* ============ Second 1-Year Time Warp ============ */

        // Move 1 year forward and check that no yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 391_011_884644);

        // `startEarningFor` hasn't been called so no wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 391_011_884644);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);
    }

    function test_morphoBlue_nonEarning_wM_as_loanToken() external {
        /* ============ Alice Creates Market ============ */

        _giveWM(_alice, 1_000_100e6);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM += 1_000_100e6);

        _give(_USDC, _alice, 1_000_100e6);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC += 1_000_100e6);

        // NOTE: Creating a market also result in `_alice` supplying 1.00 wM as supply, 1.00 USDC as collateral, and
        //       borrowing 0.90 wM.
        _createMarket(_alice, address(_wrappedMToken));

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM -= 100000);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 100000);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC -= 1e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 1e6);

        /* ============ Alice Supplies Seed wM For Loans ============ */

        _supply(_alice, address(_wrappedMToken), 1_000_000e6, _USDC);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM -= 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 1_000_000e6);

        /* ============ Bob Takes Out wM Loan Against USDC Collateral ============ */

        _give(_USDC, _bob, 1_000_000e6);

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC += 1_000_000e6);

        _supplyCollateral(_bob, _USDC, 1_000_000e6, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC -= 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 1_000_000e6);

        _borrow(_bob, address(_wrappedMToken), 900_000e6, _bob, _USDC);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM += 900_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM -= 900_000e6);

        /* ============ First 1-Year Time Warp ============ */

        // Move 1 year forward and check that no yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 383_154_367021);

        // `startEarningFor` hasn't been called so no wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 383_154_367021);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);

        /* ============ Bob Repays wM Loan And Withdraws USDC Collateral ============ */

        _repay(_bob, address(_wrappedMToken), 900_000e6, _USDC);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM -= 900_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 900_000e6);

        _withdrawCollateral(_bob, _USDC, 1_000_000e6, _bob, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC += 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC -= 1_000_000e6);

        /* ============ Alice Withdraws Seed wM For Loans ============ */

        _withdraw(_alice, address(_wrappedMToken), 1_000_000e6, _alice, _USDC);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM += 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM -= 1_000_000e6);

        /* ============ Second 1-Year Time Warp ============ */

        // Move 1 year forward and check that no yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 391_011_884644);

        // `startEarningFor` hasn't been called so no wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 391_011_884644);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);
    }

    function test_morphoBlue_earning_wM_as_collateralToken() public {
        /* ============ Alice Creates Market ============ */

        _giveWM(_alice, 1_000_100e6);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM += 1_000_100e6);

        _give(_USDC, _alice, 1_000_100e6);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC += 1_000_100e6);

        // NOTE: Creating a market also result in `_alice` supplying 1.00 USDC as supply, 1.00 wM as collateral, and
        //       borrowing 0.90 USDC.
        _createMarket(_alice, _USDC);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM -= 1e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 1e6);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC -= 100000);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 100000);

        /* ============ Alice Supplies Seed USDC For Loans ============ */

        _supply(_alice, _USDC, 1_000_000e6, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC -= 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 1_000_000e6);

        /* ============ Bob Takes Out USDC Loan Against wM Collateral ============ */

        _giveWM(_bob, 1_000_100e6);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM += 1_000_100e6);

        _supplyCollateral(_bob, address(_wrappedMToken), 1_000_000e6, _USDC);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM -= 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 1_000_000e6);

        _borrow(_bob, _USDC, 900_000e6, _bob, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC += 900_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC -= 900_000e6);

        /* ============ Morpho Becomes An Earner ============ */

        _setClaimOverrideRecipient(_MORPHO, _carol);

        _addToList(_EARNERS_LIST, _MORPHO);
        _wrappedMToken.startEarningFor(_MORPHO);

        // Check that the pool is earning wM.
        assertTrue(_wrappedMToken.isEarning(_MORPHO));

        assertEq(_wrappedMToken.claimRecipientFor(_MORPHO), _carol);

        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield);

        /* ============ First 1-Year Time Warp ============ */

        // Move 1 year forward and check that yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 383_154_367021);

        // `startEarningFor` has been called so wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield += 20_507_491868);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 362_646_875152);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);

        /* ============ Bob Repays USDC Loan And Withdraws wM Collateral ============ */

        _repay(_bob, _USDC, 900_000e6, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC -= 900_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 900_000e6);

        _withdrawCollateral(_bob, address(_wrappedMToken), 1_000_000e6, _bob, _USDC);

        // The collateral withdrawal has triggered a wM transfer and the yield has been claimed to carol for the pool.
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalanceOfWM += _morphoAccruedYield);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM += 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM -= 1_000_000e6);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield -= _morphoAccruedYield);

        /* ============ Alice Withdraws Seed USDC For Loans ============ */

        _withdraw(_alice, _USDC, 1_000_000e6, _alice, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC += 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC -= 1_000_000e6);

        // /* ============ Second 1-Year Time Warp ============ */

        // Move 1 year forward and check that yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 391_011_884644);

        // `startEarningFor` has been called so wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield += 45526);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 391_011_839116);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);
    }

    function test_morphoBlue_earning_wM_as_loanToken() public {
        /* ============ Alice Creates Market ============ */

        _giveWM(_alice, 1_000_100e6);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM += 1_000_100e6);

        _give(_USDC, _alice, 1_000_100e6);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC += 1_000_100e6);

        // NOTE: Creating a market also result in `_alice` supplying 1.00 wM as supply, 1.00 USDC as collateral, and
        //       borrowing 0.90 wM.
        _createMarket(_alice, address(_wrappedMToken));

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM -= 100000);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 100000);

        assertEq(IERC20(_USDC).balanceOf(_alice), _aliceBalanceOfUSDC -= 1e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 1e6);

        /* ============ Alice Supplies Seed wM For Loans ============ */

        _supply(_alice, address(_wrappedMToken), 1_000_000e6, _USDC);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM -= 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 1_000_000e6);

        /* ============ Bob Takes Out wM Loan Against USDC Collateral ============ */

        _give(_USDC, _bob, 1_000_000e6);

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC += 1_000_000e6);

        _supplyCollateral(_bob, _USDC, 1_000_000e6, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC -= 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC += 1_000_000e6);

        _borrow(_bob, address(_wrappedMToken), 900_000e6, _bob, _USDC);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM += 900_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM -= 900_000e6);

        /* ============ Morpho Becomes An Earner ============ */

        _setClaimOverrideRecipient(_MORPHO, _carol);

        _addToList(_EARNERS_LIST, _MORPHO);
        _wrappedMToken.startEarningFor(_MORPHO);

        // Check that the pool is earning wM.
        assertTrue(_wrappedMToken.isEarning(_MORPHO));

        assertEq(_wrappedMToken.claimRecipientFor(_MORPHO), _carol);

        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield);

        /* ============ First 1-Year Time Warp ============ */

        // Move 1 year forward and check that yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 383_154_367021);

        // `startEarningFor` has been called so wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield += 2_050_771703);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 381_103_595317);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);

        /* ============ Bob Repays wM Loan And Withdraws USDC Collateral ============ */

        _repay(_bob, address(_wrappedMToken), 900_000e6, _USDC);

        // The repay has triggered a wM transfer and the yield has been claimed to carol for the pool.
        assertEq(_wrappedMToken.balanceOf(_carol), _carolBalanceOfWM += _morphoAccruedYield);

        assertEq(_wrappedMToken.balanceOf(_bob), _bobBalanceOfWM -= 900_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM += 900_000e6);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield -= _morphoAccruedYield);

        _withdrawCollateral(_bob, _USDC, 1_000_000e6, _bob, address(_wrappedMToken));

        assertEq(IERC20(_USDC).balanceOf(_bob), _bobBalanceOfUSDC += 1_000_000e6);
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC -= 1_000_000e6);

        /* ============ Alice Withdraws Seed wM For Loans ============ */

        _withdraw(_alice, address(_wrappedMToken), 1_000_000e6, _alice, _USDC);

        assertEq(_wrappedMToken.balanceOf(_alice), _aliceBalanceOfWM += 1_000_000e6);
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM -= 1_000_000e6);

        /* ============ Second 1-Year Time Warp ============ */

        // Move 1 year forward and check that yield has accrued.
        vm.warp(vm.getBlockTimestamp() + 365 days);

        // Wrapped M is earning M and has accrued yield.
        assertEq(_mToken.balanceOf(address(_wrappedMToken)), _wrapperBalanceOfM += 391_011_884644);

        // `startEarningFor` has been called so wM yield has accrued in the pool.
        assertEq(_wrappedMToken.balanceOf(_MORPHO), _morphoBalanceOfWM);
        assertEq(_wrappedMToken.accruedYieldOf(_MORPHO), _morphoAccruedYield += 27069);

        // But excess yield has accrued in the wrapped M contract.
        assertEq(_wrappedMToken.excess(), _excess += 391_011_857572);

        // USDC balance is unchanged.
        assertEq(IERC20(_USDC).balanceOf(_MORPHO), _morphoBalanceOfUSDC);
    }

    function _createMarket(address account_, address loanToken_) internal {
        address collateralToken_ = loanToken_ == address(_wrappedMToken) ? _USDC : address(_wrappedMToken);

        _createMarket(account_, loanToken_, collateralToken_, _oracle, _LLTV);

        _supply(account_, loanToken_, 1_000000, collateralToken_);

        // NOTE: Put up arbitrarily more than necessary as collateral because Morpho contract seems to lack critical
        //       getter to determine additional collateral needed for some additional borrow amount.
        _supplyCollateral(account_, collateralToken_, 1_000000, loanToken_);

        _borrow(account_, loanToken_, 900000, account_, collateralToken_);
    }
}
