// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IERC20Extended } from "../../lib/common/src/interfaces/IERC20Extended.sol";
import { IMigratable } from "../../lib/common/src/interfaces/IMigratable.sol";

/**
 * @title  Smart M Token interface extending Extended ERC20.
 * @author M^0 Labs
 */
interface ISmartMToken is IMigratable, IERC20Extended {
    /* ============ Events ============ */

    /**
     * @notice Emitted when some yield is claim for `account` to `recipient`.
     * @param  account   The account under which yield was generated.
     * @param  recipient The account that received the yield.
     * @param  yield     The amount of yield claimed.
     */
    event Claimed(address indexed account, address indexed recipient, uint240 yield);

    /**
     * @notice Emitted when `account` set their yield claim recipient.
     * @param  account        The account that set their yield claim recipient.
     * @param  claimRecipient The account that will receive the yield.
     */
    event ClaimRecipientSet(address indexed account, address indexed claimRecipient);

    /**
     * @notice Emitted when Smart M earning is enabled.
     * @param  index The MToken index at the moment earning is enabled.
     */
    event EarningEnabled(uint128 index);

    /**
     * @notice Emitted when Smart M earning is disabled.
     * @param  index The SmartM index at the moment earning is disabled.
     */
    event EarningDisabled(uint128 index);

    /**
     * @notice Emitted when this contract's excess M is claimed.
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

    /**
     * @notice Emitted when calling `mToken.stopEarning` for an account approved as an earner.
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
     * @notice Emitted when calling `mToken.startEarning` for an account not approved as an.
     * @param  account The account that is not an approved earner.
     */
    error NotApprovedEarner(address account);

    /// @notice Emitted when the non-governance migrate function is called by a account other than the migration admin.
    error UnauthorizedMigration();

    /// @notice Emitted in an account is 0x0.
    error ZeroAccount();

    /// @notice Emitted in constructor if Earner Manager is 0x0.
    error ZeroEarnerManager();

    /// @notice Emitted in constructor if Excess Destination is 0x0.
    error ZeroExcessDestination();

    /// @notice Emitted in constructor if M Token is 0x0.
    error ZeroMToken();

    /// @notice Emitted in constructor if Migration Admin is 0x0.
    error ZeroMigrationAdmin();

    /// @notice Emitted in constructor if Registrar is 0x0.
    error ZeroRegistrar();

    /// @notice Emitted in constructor if World ID Router is 0x0.
    error ZeroWorldIDRouter();

    /// @notice Emitted if the external nullifier hash (scope) of a semaphore proof is invalid.
    error InvalidExternalNullifierHash();

    /// @notice Emitted if the semaphore signal is invalid in the context it is being used.
    error UnauthorizedSignal();

    /// @notice Emitted if the semaphore nullifier is not associated to an account.
    error NullifierNotFound();

    /// @notice Emitted performing an invalid action for an account that has an associated semaphore nullifier.
    error HasAssociatedNullifier();

    /// @notice Emitted when trying to start earning for a second account using the same semaphore identity.
    error NullifierAlreadyUsed();

    /// @notice Emitted when trying to stop earning for an account using the incorrect semaphore identity.
    error NullifierMismatch();

    /**
     * @notice Emitted when trying to start earning for an account that has already started earning.
     * @param  account The account that has already started earning.
     */
    error AlreadyEarning(address account);

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
     * @notice Claims any claimable yield for the account associated with the nullifier, to `destination`.
     * @param  destination           The account to send the yield to.
     * @param  root                  The merkle root of the semaphore group.
     * @param  groupId               The identifier of the World group.
     * @param  signalHash            The semaphore signal authorizing this action.
     * @param  nullifierHash         The semaphore nullifier unique to a semaphore identity within this scope.
     * @param  externalNullifierHash The semaphore nullifier unique to this scope.
     * @return yield                 The amount of yield claimed.
     */
    function claimWithProof(
        address destination,
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external returns (uint240 yield);

    /**
     * @notice Claims any claimable yield for the caller to `destination`, if there is no associated nullifier.
     * @param  destination The account to send the yield to.
     * @return yield       The amount of yield claimed.
     */
    function claim(address destination) external returns (uint240 yield);

    /**
     * @notice Claims any claimable yield for `account` to a set claim recipient, if there is no associated nullifier.
     * @param  account The account under which yield was generated.
     * @return yield   The amount of yield claimed.
     */
    function claimFor(address account) external returns (uint240 yield);

    /**
     * @notice Claims any excess M of this contract.
     * @return excess The amount of excess claimed.
     */
    function claimExcess() external returns (uint240 excess);

    /// @notice Enables earning of Smart M if allowed by the Registrar and if it has never been done.
    function enableEarning() external;

    /// @notice Disables earning of Smart M if disallowed by the Registrar and if it has never been done.
    function disableEarning() external;

    /**
     * @notice Starts earning for the caller if a valid proof is provided by a verified World ID identity.
     * @param  root                  The merkle root of the semaphore group.
     * @param  groupId               The identifier of the World group.
     * @param  signalHash            The semaphore signal authorizing this action.
     * @param  nullifierHash         The semaphore nullifier unique to a semaphore identity within this scope.
     * @param  externalNullifierHash The semaphore nullifier unique to this scope.
     */
    function startEarningWithProof(
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external;

    /**
     * @notice Starts earning for `account` if allowed by the Earner Manager.
     * @param  account The account to start earning for.
     */
    function startEarningFor(address account) external;

    /**
     * @notice Starts earning for multiple accounts if individually allowed by the Earner Manager.
     * @param  accounts The accounts to start earning for.
     */
    function startEarningFor(address[] calldata accounts) external;

    /**
     * @notice Stops earning for `account` if a valid proof is provided by the associated verified World ID identity.
     * @param  root                  The merkle root of the semaphore group.
     * @param  groupId               The identifier of the World group.
     * @param  signalHash            The semaphore signal authorizing this action.
     * @param  nullifierHash         The semaphore nullifier unique to a semaphore identity within this scope.
     * @param  externalNullifierHash The semaphore nullifier unique to this scope.
     */
    function stopEarningWithProof(
        address account,
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external;

    /**
     * @notice Stops earning for the caller by disassociating the verified World ID identity.
     * @param  nullifierHash The semaphore nullifier unique to a semaphore identity within this scope.
     */
    function stopEarning(uint256 nullifierHash) external;

    /// @notice Stops earning for the caller.
    function stopEarning() external;

    /**
     * @notice Stops earning for `account` if disallowed by the Earner Manager.
     * @param  account The account to stop earning for.
     */
    function stopEarningFor(address account) external;

    /**
     * @notice Stops earning for multiple accounts if individually disallowed by the Earner Manager.
     * @param  accounts The account to stop earning for.
     */
    function stopEarningFor(address[] calldata accounts) external;

    /**
     * @notice Explicitly sets the recipient of any yield claimed for the caller.
     * @param  claimRecipient The account that will receive the caller's yield.
     */
    function setClaimRecipient(address claimRecipient) external;

    /* ============ Temporary Admin Migration ============ */

    /**
     * @notice Performs an arbitrarily defined migration.
     * @param  migrator The address of a migrator contract.
     */
    function migrate(address migrator) external;

    /* ============ View/Pure Functions ============ */

    /// @notice 100% in basis points.
    function HUNDRED_PERCENT() external pure returns (uint16 hundredPercent);

    /// @notice Registrar key holding value of whether the earners list can be ignored or not.
    function EARNERS_LIST_IGNORED_KEY() external pure returns (bytes32 earnersListIgnoredKey);

    /// @notice Registrar key of earners list.
    function EARNERS_LIST_NAME() external pure returns (bytes32 earnersListName);

    /// @notice Registrar key prefix to determine the override recipient of an account's accrued yield.
    function CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX() external pure returns (bytes32 claimOverrideRecipientKeyPrefix);

    /// @notice Registrar key prefix to determine the migrator contract.
    function MIGRATOR_KEY_PREFIX() external pure returns (bytes32 migratorKeyPrefix);

    /// @notice Prefix to validate semaphore signal to start earning.
    function START_EARNING_SIGNAL_PREFIX() external pure returns (bytes32 startEarningSignalPrefix);

    /// @notice Prefix to validate semaphore signal to stop earning.
    function STOP_EARNING_SIGNAL_PREFIX() external pure returns (bytes32 stopEarningSignalPrefix);

    /// @notice Prefix to validate semaphore signal to claim yield.
    function CLAIM_SIGNAL_PREFIX() external pure returns (bytes32 claimSignalPrefix);

    /// @notice Hash to validate semaphore scope.
    function EXTERNAL_NULLIFIER_HASH() external pure returns (uint256 externalNullifierHash);

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
     * @notice Returns the earning principal of `account`.
     * @param  account          The address of some account.
     * @return earningPrincipal The earning principal of `account`.
     */
    function earningPrincipalOf(address account) external view returns (uint112 earningPrincipal);

    /**
     * @notice Returns the recipient to override as the destination for an account's claim of yield.
     * @param  account   The account being queried.
     * @return recipient The address of the recipient, if any, to override as the destination of claimed yield.
     */
    function claimRecipientFor(address account) external view returns (address recipient);

    /// @notice The current index of Smart M's earning mechanism.
    function currentIndex() external view returns (uint128 index);

    /// @notice The M token's index when earning was most recently enabled.
    function enableMIndex() external view returns (uint128 enableMIndex);

    /// @notice This contract's current excess M that is not earmarked for account balances or accrued yield.
    function excess() external view returns (uint240 excess);

    /// @notice The wrapper's index when earning was most recently disabled.
    function disableIndex() external view returns (uint128 disableIndex);

    /**
     * @notice Returns the account and nonce associated with a nullifier hash.
     * @param  nullifierHash The semaphore nullifier unique to a semaphore identity within this scope.
     * @return account       The account associated with the nullifier hash.
     * @return nonce         The next expected signal nonce for this nullifier hash.
     */
    function getNullifier(uint256 nullifierHash) external view returns (address account, uint96 nonce);

    /**
     * @notice Returns whether `account` is a wM earner.
     * @param  account   The account being queried.
     * @return isEarning true if the account has started earning.
     */
    function isEarning(address account) external view returns (bool isEarning);

    /// @notice Whether Smart M earning is enabled.
    function isEarningEnabled() external view returns (bool isEnabled);

    /// @notice The account that can bypass the Registrar and call the `migrate(address migrator)` function.
    function migrationAdmin() external view returns (address migrationAdmin);

    /// @notice The address of the M Token contract.
    function mToken() external view returns (address mToken);

    /// @notice The address of the Registrar.
    function registrar() external view returns (address registrar);

    /// @notice The address of the Earner Manager.
    function earnerManager() external view returns (address earnerManager);

    /// @notice The portion of total supply that is not earning yield.
    function totalNonEarningSupply() external view returns (uint240 totalSupply);

    /// @notice The accrued yield of the portion of total supply that is earning yield.
    function totalAccruedYield() external view returns (uint240 yield);

    /// @notice The portion of total supply that is earning yield.
    function totalEarningSupply() external view returns (uint240 totalSupply);

    /// @notice The total earning principal to help compute totalAccruedYield(), and thus excess().
    function totalEarningPrincipal() external view returns (uint112 totalEarningPrincipal);

    /// @notice The address of the destination where excess is claimed to.
    function excessDestination() external view returns (address excessDestination);

    /// @notice The address of the World ID Router to verify semaphore proofs with.
    function worldIDRouter() external view returns (address worldIDRouter);
}
