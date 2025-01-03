// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IERC20 } from "../../../../lib/common/src/interfaces/IERC20.sol";

import {
    Id,
    MarketParams,
    IMorphoBlueLike,
    IMorphoChainlinkOracleV2Factory,
    IMorphoVaultFactoryLike,
    IMorphoVaultLike
} from "./Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract MorphoTestBase is TestBase {
    uint256 internal constant _MARKET_PARAMS_BYTES_LENGTH = 5 * 32;

    // Morpho Blue factory on Ethereum Mainnet
    address internal constant _MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // Morpho Vault factory on Ethereum Mainnet
    address internal constant _MORPHO_VAULT_FACTORY = 0xA9c3D3a366466Fa809d1Ae982Fb2c46E5fC41101;

    // Oracle factory on Ethereum Mainnet
    address internal constant _ORACLE_FACTORY = 0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766;

    // Morpho Blue market Liquidation Loan-To-Value ratio
    uint256 internal constant _LLTV = 94_5000000000000000; // 94.5%

    Id internal constant _IDLE_MARKET_ID = Id.wrap(0x7725318760d6d193e11f889f0be58eba134f64a8c22ed9050cac7bd4a70a64f0);

    address internal _oracle;

    /* ============ Oracles ============ */

    function _createOracle() internal returns (address oracle_) {
        return
            IMorphoChainlinkOracleV2Factory(_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
                address(0),
                1,
                address(0),
                address(0),
                6,
                address(0),
                1,
                address(0),
                address(0),
                6,
                bytes32(0)
            );
    }

    /* ============ Markets ============ */

    function _createMarket(
        address account_,
        address loanToken_,
        address collateralToken_,
        address oracle_,
        uint256 lltv_
    ) internal {
        MarketParams memory marketParams_ = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: oracle_,
            irm: address(0),
            lltv: lltv_
        });

        vm.prank(account_);
        IMorphoBlueLike(_MORPHO).createMarket(marketParams_);
    }

    function _createIdleMarket(address account_) internal {
        _createMarket(account_, address(0), address(0), address(0), 0);
    }

    function _supplyCollateral(
        address account_,
        address collateralToken_,
        uint256 amount_,
        address loanToken_
    ) internal {
        _approve(collateralToken_, account_, _MORPHO, amount_);

        MarketParams memory marketParams_ = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: _oracle,
            irm: address(0),
            lltv: _LLTV
        });

        vm.prank(account_);
        IMorphoBlueLike(_MORPHO).supplyCollateral(marketParams_, amount_, account_, hex"");
    }

    function _withdrawCollateral(
        address account_,
        address collateralToken_,
        uint256 amount_,
        address receiver_,
        address loanToken_
    ) internal {
        MarketParams memory marketParams_ = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: _oracle,
            irm: address(0),
            lltv: _LLTV
        });

        vm.prank(account_);
        IMorphoBlueLike(_MORPHO).withdrawCollateral(marketParams_, amount_, account_, receiver_);
    }

    function _supply(
        address account_,
        address loanToken_,
        uint256 amount_,
        address collateralToken_
    ) internal returns (uint256 assetsSupplied_, uint256 sharesSupplied_) {
        _approve(loanToken_, account_, _MORPHO, amount_);

        MarketParams memory marketParams_ = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: _oracle,
            irm: address(0),
            lltv: _LLTV
        });

        vm.prank(account_);
        return IMorphoBlueLike(_MORPHO).supply(marketParams_, amount_, 0, account_, hex"");
    }

    function _withdraw(
        address account_,
        address loanToken_,
        uint256 amount_,
        address receiver_,
        address collateralToken_
    ) internal returns (uint256 assetsWithdrawn_, uint256 sharesWithdrawn_) {
        MarketParams memory marketParams_ = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: _oracle,
            irm: address(0),
            lltv: _LLTV
        });

        vm.prank(account_);
        return IMorphoBlueLike(_MORPHO).withdraw(marketParams_, amount_, 0, account_, receiver_);
    }

    function _borrow(
        address account_,
        address loanToken_,
        uint256 amount_,
        address receiver_,
        address collateralToken_
    ) internal returns (uint256 assetsBorrowed_, uint256 sharesBorrowed_) {
        MarketParams memory marketParams_ = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: _oracle,
            irm: address(0),
            lltv: _LLTV
        });

        vm.prank(account_);
        return IMorphoBlueLike(_MORPHO).borrow(marketParams_, amount_, 0, account_, receiver_);
    }

    function _repay(
        address account_,
        address loanToken_,
        uint256 amount_,
        address collateralToken_
    ) internal returns (uint256 assetsRepaid_, uint256 sharesRepaid_) {
        _approve(loanToken_, account_, _MORPHO, amount_);

        MarketParams memory marketParams_ = MarketParams({
            loanToken: loanToken_,
            collateralToken: collateralToken_,
            oracle: _oracle,
            irm: address(0),
            lltv: _LLTV
        });

        vm.prank(account_);
        return IMorphoBlueLike(_MORPHO).repay(marketParams_, amount_, 0, account_, hex"");
    }

    function _getMarketId(MarketParams memory marketParams_) internal pure returns (Id marketParamsId_) {
        assembly ("memory-safe") {
            marketParamsId_ := keccak256(marketParams_, _MARKET_PARAMS_BYTES_LENGTH)
        }
    }

    /* ============ ERC20 ============ */

    function _approve(address token_, address account_, address spender_, uint256 amount_) internal {
        vm.prank(account_);
        IERC20(token_).approve(spender_, amount_);
    }

    function _transfer(address token_, address sender_, address recipient_, uint256 amount_) internal {
        vm.prank(sender_);
        IERC20(token_).transfer(recipient_, amount_);
    }
}
