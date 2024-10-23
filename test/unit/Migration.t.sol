// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IWrappedMToken } from "../../src/interfaces/IWrappedMToken.sol";

import { WrappedMToken } from "../../src/WrappedMToken.sol";
import { Proxy } from "../../src/Proxy.sol";

import { MockM, MockRegistrar } from "./../utils/Mocks.sol";

contract WrappedMTokenV3 {
    function foo() external pure returns (uint256) {
        return 1;
    }
}

contract WrappedMTokenMigratorV2 {
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public immutable implementationV2;

    constructor(address implementationV3_) {
        implementationV2 = implementationV3_;
    }

    fallback() external virtual {
        address implementationV3_ = implementationV2;

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementationV3_)
        }
    }
}

contract MigrationTests is Test {
    uint56 internal constant _EXP_SCALED_ONE = 1e12;

    bytes32 internal constant _MIGRATOR_V2_PREFIX = "wm_migrator_v2";

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");

    address internal _excessDestination = makeAddr("excessDestination");
    address internal _migrationAdmin = makeAddr("migrationAdmin");

    MockM internal _mToken;
    MockRegistrar internal _registrar;
    WrappedMToken internal _implementation;
    IWrappedMToken internal _wrappedMToken;

    function setUp() external {
        _registrar = new MockRegistrar();

        _mToken = new MockM();
        _mToken.setCurrentIndex(_EXP_SCALED_ONE);

        _implementation = new WrappedMToken(address(_mToken), address(_registrar), _excessDestination, _migrationAdmin);

        _wrappedMToken = IWrappedMToken(address(new Proxy(address(_implementation))));
    }

    function test_migration() external {
        WrappedMTokenV3 implementationV3_ = new WrappedMTokenV3();
        address migrator_ = address(new WrappedMTokenMigratorV2(address(implementationV3_)));

        _registrar.set(
            keccak256(abi.encode(_MIGRATOR_V2_PREFIX, address(_wrappedMToken))),
            bytes32(uint256(uint160(migrator_)))
        );

        vm.expectRevert();
        WrappedMTokenV3(address(_wrappedMToken)).foo();

        _wrappedMToken.migrate();

        assertEq(WrappedMTokenV3(address(_wrappedMToken)).foo(), 1);
    }

    function test_migration_fromAdmin() external {
        WrappedMTokenV3 implementationV3_ = new WrappedMTokenV3();
        address migrator_ = address(new WrappedMTokenMigratorV2(address(implementationV3_)));

        vm.expectRevert();
        WrappedMTokenV3(address(_wrappedMToken)).foo();

        vm.prank(_migrationAdmin);
        _wrappedMToken.migrate(migrator_);

        assertEq(WrappedMTokenV3(address(_wrappedMToken)).foo(), 1);
    }
}
