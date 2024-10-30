// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/**
 * @title  Migrator contract for migrating a WrappedMToken contract from V1 to V2.
 * @author M^0 Labs
 */
contract WrappedMTokenMigratorV1 {
    /// @dev Storage slot with the address of the current factory. `keccak256('eip1967.proxy.implementation') - 1`.
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public immutable implementationV2;

    constructor(address implementationV2_) {
        implementationV2 = implementationV2_;
    }

    fallback() external virtual {
        address implementationV2_ = implementationV2;

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementationV2_)
        }
    }
}
