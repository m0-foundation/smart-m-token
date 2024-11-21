// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { IndexingMath } from "../../lib/common/src/libs/IndexingMath.sol";
// import { console2 } from "../../lib/forge-std/src/Test.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { ISmartMToken } from "../../src/interfaces/ISmartMToken.sol";

library Invariants {
    // Invariant 1: Sum of all accounts' balances is equal to total supply.
    // Invariant 1a: Sum of all non-earning accounts' balances is equal to total non-earning supply.
    // Invariant 1b: Sum of all earning accounts' balances is equal to total earning supply.
    function checkInvariant1(address smartMToken_, address[] memory accounts_) internal view returns (bool success_) {
        uint256 totalNonEarningSupply_;
        uint256 totalEarningSupply_;
        uint256 totalSupply_;

        for (uint256 i_; i_ < accounts_.length; ++i_) {
            address account_ = accounts_[i_];
            uint256 balance_ = ISmartMToken(smartMToken_).balanceOf(account_);

            totalSupply_ += balance_;

            if (ISmartMToken(smartMToken_).isEarning(account_)) {
                totalEarningSupply_ += balance_;
            } else {
                totalNonEarningSupply_ += balance_;
            }
        }

        // console2.log("Invariant 1: totalNonEarningSupply_  = %d", totalNonEarningSupply_);
        // console2.log(
        //     "Invariant 1: totalNonEarningSupply() = %d",
        //     ISmartMToken(smartMToken_).totalNonEarningSupply()
        // );

        if (totalNonEarningSupply_ != ISmartMToken(smartMToken_).totalNonEarningSupply()) return false;

        // console2.log("Invariant 1: totalEarningSupply_  = %d", totalEarningSupply_);
        // console2.log("Invariant 1: totalEarningSupply() = %d", ISmartMToken(smartMToken_).totalEarningSupply());

        if (totalEarningSupply_ != ISmartMToken(smartMToken_).totalEarningSupply()) return false;

        // console2.log("Invariant 1: totalSupply_  = %d", totalSupply_);
        // console2.log("Invariant 1: totalSupply() = %d", ISmartMToken(smartMToken_).totalSupply());

        if (totalSupply_ != ISmartMToken(smartMToken_).totalSupply()) return false;

        return true;
    }

    // Invariant 2: Sum of all accounts' accrued yield is less than or equal to total accrued yield.
    function checkInvariant2(address smartMToken_, address[] memory accounts_) internal view returns (bool success_) {
        uint256 totalAccruedYield_;

        for (uint256 i_; i_ < accounts_.length; ++i_) {
            totalAccruedYield_ += ISmartMToken(smartMToken_).accruedYieldOf(accounts_[i_]);
        }

        // console2.log("Invariant 2: totalAccruedYield_  = %d", totalAccruedYield_);

        // console2.log("Invariant 2: totalAccruedYield() = %d", ISmartMToken(smartMToken_).totalAccruedYield());

        return ISmartMToken(smartMToken_).totalAccruedYield() >= totalAccruedYield_;
    }

    // Invariant 3: M Balance of wrapper is greater or equal to total supply, accrued yield, and excess.
    function checkInvariant3(address smartMToken_, address mToken_) internal view returns (bool success_) {
        // console2.log(
        //     "Invariant 3: M Balance of wrapper                           = %d ",
        //     IERC20(mToken_).balanceOf(smartMToken_)
        // );

        // console2.log(
        //     "Invariant 3: totalSupply() + totalAccruedYield() + excess() = %d",
        //     ISmartMToken(smartMToken_).totalSupply() +
        //         ISmartMToken(smartMToken_).totalAccruedYield() +
        //         ISmartMToken(smartMToken_).excess()
        // );

        return
            IERC20(mToken_).balanceOf(smartMToken_) >=
            ISmartMToken(smartMToken_).totalSupply() +
                ISmartMToken(smartMToken_).totalAccruedYield() +
                ISmartMToken(smartMToken_).excess();
    }

    // Invariant 4: Sum of all earning accounts' principals is less than or equal to principal of total earning supply.
    function checkInvariant4(address smartMToken_, address[] memory accounts_) internal view returns (bool success_) {
        uint256 totalEarningPrincipal_;

        for (uint256 i_; i_ < accounts_.length; ++i_) {
            address account_ = accounts_[i_];

            if (!ISmartMToken(smartMToken_).isEarning(account_)) continue;

            totalEarningPrincipal_ += ISmartMToken(smartMToken_).earningPrincipalOf(account_);
        }

        // console2.log("Invariant 2: totalEarningPrincipal_ = %d", totalEarningPrincipal_);

        // console2.log(
        //     "Invariant 2: totalEarningPrincipal()         = %d",
        //     ISmartMToken(smartMToken_).totalEarningPrincipal()
        // );

        return ISmartMToken(smartMToken_).totalEarningPrincipal() >= totalEarningPrincipal_;
    }
}
