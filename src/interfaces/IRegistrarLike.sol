// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/**
 * @title  Subset of Registrar interface required for source contracts.
 * @author M^0 Labs
 */
interface IRegistrarLike {
    /* ============ View/Pure Functions ============ */

    /**
     * @notice Returns the value of `key`.
     * @param  key   Some key.
     * @return value Some value.
     */
    function get(bytes32 key) external view returns (bytes32 value);

    /**
     * @notice Returns whether `list` contains `account` or not.
     * @param  list     The key for some list.
     * @param  account  The address of some account.
     * @return contains Whether `list` contains `account` or not.
     */
    function listContains(bytes32 list, address account) external view returns (bool contains);
}
