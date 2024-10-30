// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IERC20Extended } from "../../lib/common/src/interfaces/IERC20Extended.sol";

import { IMigratable } from "./IMigratable.sol";

/**
 * @title  Wrapped M Token interface extending Extended ERC20.
 * @author M^0 Labs
 */
interface IWrappedMToken is IMigratable, IERC20Extended {
    /* ============ Events ============ */

    /**
     * @notice Emitted when some yield is claim for `account` to `recipient`.
     * @param  account   The account under which yield was generated.
     * @param  recipient The account that received the yield.
     * @param  yield     The amount of yield claimed.
     */
    event Claimed(address indexed account, address indexed recipient, uint240 yield);

    /**
     * @notice Emitted when earning is enabled for the entire wrapper.
     * @param  index The index at the moment earning is enabled.
     */
    event EarningEnabled(uint128 index);

    /**
     * @notice Emitted when earning is disabled for the entire wrapper.
     * @param  index The index at the moment earning is disabled.
     */
    event EarningDisabled(uint128 index);

    /**
     * @notice Emitted when the wrapper's excess M is claimed.
     * @param  excess The amount of excess M claimed.
     */
    event ExcessClaimed(uint240 excess);

    /**
     * @notice Emitted when `account` starts being an wM earner.
     * @param  account The account that started earning.
     */
    event StartedEarning(address indexed account);

    /**
     * @notice Emitted when `account` stops being an wM earner.
     * @param  account The account that stopped earning.
     */
    event StoppedEarning(address indexed account);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when performing an operation that is not allowed when earning is disabled.
    error EarningIsDisabled();

    /// @notice Emitted when performing an operation that is not allowed when earning is enabled.
    error EarningIsEnabled();

    /// @notice Emitted when trying to enable earning after it has been explicitly disabled.
    error EarningCannotBeReenabled();

    /**
     * @notice Emitted when calling `stopEarning` for an account approved as earner by the Registrar.
     * @param  account The account that is an approved earner.
     */
    error IsApprovedEarner(address account);

    /**
     * @notice Emitted when there is insufficient balance to decrement from `account`.
     * @param  account The account with insufficient balance.
     * @param  balance The balance of the account.
     * @param  amount  The amount to decrement.
     */
    error InsufficientBalance(address account, uint240 balance, uint240 amount);

    /**
     * @notice Emitted when calling `startEarning` for an account not approved as earner by the Registrar.
     * @param  account The account that is not an approved earner.
     */
    error NotApprovedEarner(address account);

    /// @notice Emitted when the non-governance migrate function is called by a account other than the migration admin.
    error UnauthorizedMigration();

    /// @notice Emitted in constructor if Excess Destination is 0x0.
    error ZeroExcessDestination();

    /// @notice Emitted in constructor if M Token is 0x0.
    error ZeroMToken();

    /// @notice Emitted in constructor if Migration Admin is 0x0.
    error ZeroMigrationAdmin();

    /// @notice Emitted in constructor if Registrar is 0x0.
    error ZeroRegistrar();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Wraps `amount` M from the caller into wM for `recipient`.
     * @param  recipient The account receiving the minted wM.
     * @param  amount    The amount of M deposited.
     * @return wrapped   The amount of wM minted.
     */
    function wrap(address recipient, uint256 amount) external returns (uint240 wrapped);

    /**
     * @notice Wraps all the M from the caller into wM for `recipient`.
     * @param  recipient The account receiving the minted wM.
     * @return wrapped   The amount of wM minted.
     */
    function wrap(address recipient) external returns (uint240 wrapped);

    /**
     * @notice Wraps `amount` M from the caller into wM for `recipient`, using a permit.
     * @param  recipient The account receiving the minted wM.
     * @param  amount    The amount of M deposited.
     * @param  deadline  The last timestamp where the signature is still valid.
     * @param  v         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  r         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @param  s         An ECDSA secp256k1 signature parameter (EIP-2612 via EIP-712).
     * @return wrapped   The amount of wM minted.
     */
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint240 wrapped);

    /**
     * @notice Wraps `amount` M from the caller into wM for `recipient`, using a permit.
     * @param  recipient The account receiving the minted wM.
     * @param  amount    The amount of M deposited.
     * @param  deadline  The last timestamp where the signature is still valid.
     * @param  signature An arbitrary signature (EIP-712).
     * @return wrapped   The amount of wM minted.
     */
    function wrapWithPermit(
        address recipient,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) external returns (uint240 wrapped);

    /**
     * @notice Unwraps `amount` wM from the caller into M for `recipient`.
     * @param  recipient The account receiving the withdrawn M.
     * @param  amount    The amount of wM burned.
     * @return unwrapped The amount of M withdrawn.
     */
    function unwrap(address recipient, uint256 amount) external returns (uint240 unwrapped);

    /**
     * @notice Unwraps all the wM from the caller into M for `recipient`.
     * @param  recipient The account receiving the withdrawn M.
     * @return unwrapped The amount of M withdrawn.
     */
    function unwrap(address recipient) external returns (uint240 unwrapped);

    /**
     * @notice Claims any claimable yield for `account`.
     * @param  account The account under which yield was generated.
     * @return yield   The amount of yield claimed.
     */
    function claimFor(address account) external returns (uint240 yield);

    /**
     * @notice Claims any excess M of the wrapper.
     * @return excess The amount of excess claimed.
     */
    function claimExcess() external returns (uint240 excess);

    /// @notice Enables earning for the wrapper if allowed by the Registrar and if it has never been done.
    function enableEarning() external;

    /// @notice Disables earning for the wrapper if disallowed by the Registrar and if it has never been done.
    function disableEarning() external;

    /**
     * @notice Starts earning for `account` if allowed by the Registrar.
     * @param  account The account to start earning for.
     */
    function startEarningFor(address account) external;

    /**
     * @notice Starts earning for multiple accounts if individually allowed by the Registrar.
     * @param  accounts The accounts to start earning for.
     */
    function startEarningFor(address[] calldata accounts) external;

    /**
     * @notice Stops earning for `account` if disallowed by the Registrar.
     * @param  account The account to stop earning for.
     */
    function stopEarningFor(address account) external;

    /**
     * @notice Stops earning for multiple accounts if individually disallowed by the Registrar.
     * @param  accounts The account to stop earning for.
     */
    function stopEarningFor(address[] calldata accounts) external;

    /* ============ Temporary Admin Migration ============ */

    /**
     * @notice Performs an arbitrarily defined migration.
     * @param  migrator The address of a migrator contract.
     */
    function migrate(address migrator) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Registrar key holding value of whether the earners list can be ignored or not.
    function EARNERS_LIST_IGNORED_KEY() external pure returns (bytes32 earnersListIgnoredKey);

    /// @notice Registrar key of earners list.
    function EARNERS_LIST_NAME() external pure returns (bytes32 earnersListName);

    /// @notice Registrar key prefix to determine the override recipient of an account's accrued yield.
    function CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX() external pure returns (bytes32 claimOverrideRecipientKeyPrefix);

    /// @notice Registrar key prefix to determine the migrator contract.
    function MIGRATOR_KEY_PREFIX() external pure returns (bytes32 migratorKeyPrefix);

    /**
     * @notice Returns the yield accrued for `account`, which is claimable.
     * @param  account The account being queried.
     * @return yield   The amount of yield that is claimable.
     */
    function accruedYieldOf(address account) external view returns (uint240 yield);

    /**
     * @notice Returns the token balance of `account` including any accrued yield.
     * @param  account The address of some account.
     * @return balance The token balance of `account` including any accrued yield.
     */
    function balanceWithYieldOf(address account) external view returns (uint256 balance);

    /**
     * @notice Returns the last index of `account`.
     * @param  account   The address of some account.
     * @return lastIndex The last index of `account`, 0 if the account is not earning.
     */
    function lastIndexOf(address account) external view returns (uint128 lastIndex);

    /**
     * @notice Returns the recipient to override as the destination for an account's claim of yield.
     * @param  account   The account being queried.
     * @return recipient The address of the recipient, if any, to override as the destination of claimed yield.
     */
    function claimOverrideRecipientFor(address account) external view returns (address recipient);

    /// @notice The current index of the wrapper's earning mechanism.
    function currentIndex() external view returns (uint128 index);

    /// @notice The current excess M of the wrapper that is not earmarked for account balances or accrued yield.
    function excess() external view returns (uint240 excess);

    /**
     * @notice Returns whether `account` is a wM earner.
     * @param  account   The account being queried.
     * @return isEarning true if the account has started earning.
     */
    function isEarning(address account) external view returns (bool isEarning);

    /// @notice Whether earning is enabled for the entire wrapper.
    function isEarningEnabled() external view returns (bool isEnabled);

    /// @notice Whether earning has been enabled at least once or not.
    function wasEarningEnabled() external view returns (bool wasEnabled);

    /// @notice The account that can bypass the Registrar and call the `migrate(address migrator)` function.
    function migrationAdmin() external view returns (address migrationAdmin);

    /// @notice The address of the M Token contract.
    function mToken() external view returns (address mToken);

    /// @notice The address of the Registrar.
    function registrar() external view returns (address registrar);

    /// @notice The portion of total supply that is not earning yield.
    function totalNonEarningSupply() external view returns (uint240 totalSupply);

    /// @notice The accrued yield of the portion of total supply that is earning yield.
    function totalAccruedYield() external view returns (uint240 yield);

    /// @notice The portion of total supply that is earning yield.
    function totalEarningSupply() external view returns (uint240 totalSupply);

    /// @notice The principal of totalEarningSupply to help compute totalAccruedYield(), and thus excess().
    function principalOfTotalEarningSupply() external view returns (uint112 principalOfTotalEarningSupply);

    /// @notice The address of the destination where excess is claimed to.
    function excessDestination() external view returns (address excessDestination);
}
