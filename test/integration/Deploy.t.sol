// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IWrappedMToken } from "../../src/interfaces/IWrappedMToken.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";

import { DeployBase } from "../../script/DeployBase.sol";

contract Deploy is Test, DeployBase {
    address internal constant _REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address internal constant _M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _MIGRATION_ADMIN = 0x431169728D75bd02f4053435b87D15c8d1FB2C72;
    address internal constant _EXCESS_DESTINATION = 0xd7298f620B0F752Cf41BD818a16C756d9dCAA34f; // Vault
    address internal constant _DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;
    uint256 internal constant _DEPLOYER_NONCE = 50;

    function test_deploy() external {
        vm.setNonce(_DEPLOYER, uint64(_DEPLOYER_NONCE));

        vm.startPrank(_DEPLOYER);
        (address implementation_, address proxy_) = deploy(_M_TOKEN, _REGISTRAR, _EXCESS_DESTINATION, _MIGRATION_ADMIN);
        vm.stopPrank();

        // Wrapped M Token Implementation assertions
        assertEq(implementation_, getExpectedWrappedMTokenImplementation(_DEPLOYER, _DEPLOYER_NONCE));
        assertEq(IWrappedMToken(implementation_).migrationAdmin(), _MIGRATION_ADMIN);
        assertEq(IWrappedMToken(implementation_).mToken(), _M_TOKEN);
        assertEq(IWrappedMToken(implementation_).registrar(), _REGISTRAR);
        assertEq(IWrappedMToken(implementation_).excessDestination(), _EXCESS_DESTINATION);

        // Wrapped M Token Proxy assertions
        assertEq(proxy_, getExpectedWrappedMTokenProxy(_DEPLOYER, _DEPLOYER_NONCE));
        assertEq(IWrappedMToken(proxy_).migrationAdmin(), _MIGRATION_ADMIN);
        assertEq(IWrappedMToken(proxy_).mToken(), _M_TOKEN);
        assertEq(IWrappedMToken(proxy_).registrar(), _REGISTRAR);
        assertEq(IWrappedMToken(proxy_).excessDestination(), _EXCESS_DESTINATION);
    }
}
