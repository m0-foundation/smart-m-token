// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test, console2 } from "../lib/forge-std/src/Test.sol";

import { IMToken } from "../src/interfaces/IMToken.sol";
import { IWorldDollar } from "../src/interfaces/IWorldDollar.sol";

import { DeployBase } from "../script/DeployBase.sol";

contract Deploy is Test, DeployBase {
    address internal constant _DEPLOYER = 0x5CbB32455958A1AD589Bde61C72963D936b3Bcc3;

    address internal constant _WORLD_ID_ROUTER = 0x57f928158C3EE7CDad1e4D8642503c4D0201f611;

    string internal constant _APP_ID = "app_631f4131a3d7a8e447ba9ce807d32e02";

    string internal constant _ACTION = "earning";

    uint32 internal constant _EARNER_RATE = 500;

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");

    function test_deploy() external {
        vm.startPrank(_DEPLOYER);

        (address mToken_, address worldDollarImplementation_, address worldDollarProxy_) = deploy(
            _APP_ID,
            _ACTION,
            _WORLD_ID_ROUTER,
            _EARNER_RATE
        );

        vm.stopPrank();

        console2.log("Chain ID:", block.chainid);
        console2.log("Mock M Token address:", mToken_);
        console2.log("World Dollar Implementation address:", worldDollarImplementation_);
        console2.log("World Dollar Proxy address:", worldDollarProxy_);

        assertEq(IMToken(mToken_).earnerRate(), _EARNER_RATE);
        assertEq(IMToken(mToken_).minter(), _DEPLOYER);
        assertEq(IMToken(mToken_).name(), "Mock M by M^0");
        assertEq(IMToken(mToken_).symbol(), "M");
        assertEq(IMToken(mToken_).currentIndex(), 1e12);

        assertTrue(IMToken(mToken_).isEarning(worldDollarProxy_));

        assertEq(IWorldDollar(worldDollarProxy_).mToken(), mToken_);
        assertEq(IWorldDollar(worldDollarProxy_).migrationAdmin(), _DEPLOYER);
        assertEq(IWorldDollar(worldDollarProxy_).worldIDRouter(), _WORLD_ID_ROUTER);
        assertEq(IWorldDollar(worldDollarProxy_).name(), "World Dollar");
        assertEq(IWorldDollar(worldDollarProxy_).symbol(), "WorldUSD");
        assertEq(IWorldDollar(worldDollarProxy_).currentIndex(), 1e12);

        uint256 expectedExternalNullifier_ = _hashToField(
            abi.encodePacked(_hashToField(abi.encodePacked(_APP_ID)), _ACTION)
        );

        assertEq(IWorldDollar(worldDollarProxy_).externalNullifier(), expectedExternalNullifier_);

        console2.log("External Nullifier:", IWorldDollar(worldDollarProxy_).externalNullifier());

        /* ============ Some Arbitrary Story Tests Beyond This Point ============ */

        vm.startPrank(_DEPLOYER);
        IMToken(mToken_).mint(_alice, 1_000e6);
        vm.stopPrank();

        assertEq(IMToken(mToken_).balanceOf(_alice), 1_000e6);

        vm.warp(vm.getBlockTimestamp() + 100 days);

        assertEq(IMToken(mToken_).currentIndex(), 1_013792886271);
        assertEq(IWorldDollar(worldDollarProxy_).currentIndex(), 1_013792886271);

        assertEq(IMToken(mToken_).balanceOf(_alice), 1_000e6);

        vm.startPrank(_DEPLOYER);
        IMToken(mToken_).startEarning(_alice);
        vm.stopPrank();

        assertEq(IMToken(mToken_).balanceOf(_alice), 999_999999);

        vm.startPrank(_DEPLOYER);
        IMToken(mToken_).setEarnerRate(1_000);
        vm.stopPrank();

        assertEq(IMToken(mToken_).earnerRate(), 1_000);

        assertEq(IMToken(mToken_).balanceOf(_alice), 999_999999);

        assertEq(IMToken(mToken_).currentIndex(), 1_013792886271);
        assertEq(IWorldDollar(worldDollarProxy_).currentIndex(), 1_013792886271);

        vm.warp(vm.getBlockTimestamp() + 100 days);

        assertEq(IMToken(mToken_).currentIndex(), 1_041952013959);
        assertEq(IWorldDollar(worldDollarProxy_).currentIndex(), 1_041952013959);

        assertEq(IMToken(mToken_).balanceOf(_alice), 1_027_776016);

        vm.startPrank(_alice);
        IMToken(mToken_).approve(worldDollarProxy_, 500e6);
        IWorldDollar(worldDollarProxy_).wrap(_alice, 500e6);
        vm.stopPrank();

        assertEq(IMToken(mToken_).balanceOf(_alice), 527_776016);
        assertEq(IWorldDollar(worldDollarProxy_).balanceOf(_alice), 500e6);

        vm.warp(vm.getBlockTimestamp() + 100 days);

        assertEq(IMToken(mToken_).currentIndex(), 1_070893290036);
        assertEq(IWorldDollar(worldDollarProxy_).currentIndex(), 1_070893290036);

        assertEq(IMToken(mToken_).balanceOf(_alice), 542_435531);
        assertEq(IWorldDollar(worldDollarProxy_).balanceOf(_alice), 500e6);

        vm.startPrank(_alice);
        IMToken(mToken_).transfer(_bob, 250e6);
        IWorldDollar(worldDollarProxy_).transfer(_bob, 250e6);
        vm.stopPrank();

        assertEq(IMToken(mToken_).balanceOf(_alice), 292_435531);
        assertEq(IWorldDollar(worldDollarProxy_).balanceOf(_alice), 250e6);

        assertEq(IMToken(mToken_).balanceOf(_bob), 250e6);
        assertEq(IWorldDollar(worldDollarProxy_).balanceOf(_bob), 250e6);

        vm.warp(vm.getBlockTimestamp() + 100 days);

        assertEq(IMToken(mToken_).currentIndex(), 1_100638439470);
        assertEq(IWorldDollar(worldDollarProxy_).currentIndex(), 1_100638439470);

        assertEq(IMToken(mToken_).balanceOf(_alice), 300_558225);
        assertEq(IWorldDollar(worldDollarProxy_).balanceOf(_alice), 250e6);

        assertEq(IMToken(mToken_).balanceOf(_bob), 250e6);
        assertEq(IWorldDollar(worldDollarProxy_).balanceOf(_bob), 250e6);

        assertEq(
            IMToken(mToken_).totalEarningSupply(),
            IMToken(mToken_).balanceOf(_alice) + IMToken(mToken_).balanceOf(worldDollarProxy_) + 1
        );

        assertEq(IMToken(mToken_).totalNonEarningSupply(), IMToken(mToken_).balanceOf(_bob));

        assertEq(
            IWorldDollar(worldDollarProxy_).excess(),
            IMToken(mToken_).balanceOf(worldDollarProxy_) - IWorldDollar(worldDollarProxy_).totalSupply() - 1
        );
    }

    function _hashToField(bytes memory value_) internal pure returns (uint256 hash_) {
        return uint256(keccak256(value_)) >> 8;
    }
}
