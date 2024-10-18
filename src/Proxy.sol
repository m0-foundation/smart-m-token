// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/**
 * @title  Minimal transparent proxy.
 * @author M^0 Labs
 */
contract Proxy {
    /// @dev Storage slot with the address of the current factory. `keccak256('eip1967.proxy.implementation') - 1`.
    uint256 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev   Constructs the contract given the address of some implementation.
     * @param implementation_ The address of some implementation.
     */
    constructor(address implementation_) {
        if (implementation_ == address(0)) revert();

        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }
    }

    fallback() external payable virtual {
        bytes32 implementation_;

        assembly {
            implementation_ := sload(_IMPLEMENTATION_SLOT)
        }

        assembly {
            calldatacopy(0, 0, calldatasize())

            let result_ := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result_
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
