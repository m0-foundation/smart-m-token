// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IMigratable } from "./IMigratable.sol";

/**
 * @title  Earner Status Manager interface for setting and returning earner status for Wrapped M Token accounts.
 * @author M^0 Labs
 */
interface IEarnerManager is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the earner for `account` is set to `status`.
     * @param  account The account under which yield could generate.
     * @param  status  Whether the account is set as an earner, according to the admin.
     * @param  admin   The admin who set the details and who will collect the fee.
     * @param  feeRate The fee rate to be taken from the yield.
     */
    event EarnerDetailsSet(address indexed account, bool indexed status, address indexed admin, uint16 feeRate);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when `account` is already in the earners list, so it cannot be added by an admin.
    error AlreadyInRegistrarEarnersList(address account);

    /// @notice Emitted when the lengths of input arrays do not match.
    error ArrayLengthMismatch();

    /// @notice Emitted when the length of an input array is 0.
    error ArrayLengthZero();

    /// @notice Emitted when the earner details have already be set by an existing and active admin.
    error EarnerDetailsAlreadySet(address account);

    /// @notice Emitted when the earners lists are ignored, thus not requiring admin to define earners.
    error EarnersListsIgnored();

    /// @notice Emitted when the fee rate provided is to high (higher than 100% in basis points).
    error FeeRateTooHigh();

    /// @notice Emitted when setting fee rate to a nonzero value while setting status to false.
    error InvalidDetails();

    /// @notice Emitted when the caller is not an admin.
    error NotAdmin();

    /// @notice Emitted when the non-governance migrate function is called by a account other than the migration admin.
    error UnauthorizedMigration();

    /// @notice Emitted when an account (whose status is being set) is 0x0.
    error ZeroAccount();

    /// @notice Emitted in constructor if Migration Admin is 0x0.
    error ZeroMigrationAdmin();

    /// @notice Emitted in constructor if Registrar is 0x0.
    error ZeroRegistrar();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sets the status for `account` to `status`.
     * @param  account The account under which yield could generate.
     * @param  status  Whether the account is an earner, according to the admin.
     * @param  feeRate The fee rate to be taken from the yield.
     */
    function setEarnerDetails(address account, bool status, uint16 feeRate) external;

    /**
     * @notice Sets the status for multiple accounts.
     * @param  accounts The accounts under which yield could generate.
     * @param  statuses Whether each account is an earner, respectively, according to the admin.
     * @param  feeRates The fee rates to be taken from the yield, respectively.
     */
    function setEarnerDetails(
        address[] calldata accounts,
        bool[] calldata statuses,
        uint16[] calldata feeRates
    ) external;

    /* ============ Temporary Admin Migration ============ */

    /**
     * @notice Performs an arbitrarily defined migration.
     * @param  migrator The address of a migrator contract.
     */
    function migrate(address migrator) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Maximum fee rate that can be set (100% in basis points).
    function MAX_FEE_RATE() external pure returns (uint16 maxFeeRate);

    /// @notice Registrar name of admins list.
    function ADMINS_LIST_NAME() external pure returns (bytes32 adminsListName);

    /// @notice Registrar key holding value of whether the earners list can be ignored or not.
    function EARNERS_LIST_IGNORED_KEY() external pure returns (bytes32 earnersListIgnoredKey);

    /// @notice Registrar name of earners list.
    function EARNERS_LIST_NAME() external pure returns (bytes32 earnersListName);

    /// @notice Registrar key prefix to determine the migrator contract.
    function MIGRATOR_KEY_PREFIX() external pure returns (bytes32 migratorKeyPrefix);

    /**
     * @notice Returns the earner status for `account`.
     * @param  account The account being queried.
     * @return status  Whether the account is an earner.
     */
    function earnerStatusFor(address account) external view returns (bool status);

    /**
     * @notice Returns the statuses for multiple accounts.
     * @param  accounts The accounts being queried.
     * @return statuses Whether each account is an earner, respectively.
     */
    function earnerStatusesFor(address[] calldata accounts) external view returns (bool[] memory statuses);

    /**
     * @notice Returns whether the lists of earners can be ignored (thus making all accounts earners).
     * @return ignored Whether the lists of earners can be ignored.
     */
    function earnersListsIgnored() external view returns (bool ignored);

    /**
     * @notice Returns whether `account` is a Registrar-approved earner.
     * @param  account  The account being queried.
     * @return isInList Whether the account is a Registrar-approved earner.
     */
    function isInRegistrarEarnersList(address account) external view returns (bool isInList);

    /**
     * @notice Returns whether `account` is an Admin-approved earner.
     * @param  account  The account being queried.
     * @return isInList Whether the account is an Admin-approved earner.
     */
    function isInAdministratedEarnersList(address account) external view returns (bool isInList);

    /**
     * @notice Returns the earner details for `account`.
     * @param  account The account being queried.
     * @return status  Whether the account is an earner.
     * @return feeRate The fee rate to be taken from the yield.
     * @return admin   The admin who set the details and who will collect the fee.
     */
    function getEarnerDetails(address account) external view returns (bool status, uint16 feeRate, address admin);

    /**
     * @notice Returns the earner details for multiple accounts, according to an admin.
     * @param  accounts The accounts being queried.
     * @return statuses Whether each account is an earner, respectively.
     * @return feeRates The fee rates to be taken from the yield, respectively.
     * @return admins   The admin who set the details and who will collect the fee, respectively.
     */
    function getEarnerDetails(
        address[] calldata accounts
    ) external view returns (bool[] memory statuses, uint16[] memory feeRates, address[] memory admins);

    /**
     * @notice Returns whether `account` is an admin.
     * @param  account The address of an account.
     * @return isAdmin Whether the account is an admin.
     */
    function isAdmin(address account) external view returns (bool isAdmin);

    /// @notice The account that can bypass the Registrar and call the `migrate(address migrator)` function.
    function migrationAdmin() external view returns (address migrationAdmin);

    /// @notice Returns the address of the Registrar.
    function registrar() external view returns (address);
}
