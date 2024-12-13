// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IERC20Extended } from "../../lib/common/src/interfaces/IERC20Extended.sol";
import { IMigratable } from "../../lib/common/src/interfaces/IMigratable.sol";

/**
 * @title  World Dollar interface extending Extended ERC20.
 * @author M^0 Labs
 */
interface IWorldDollar is IMigratable, IERC20Extended {
    /* ============ Events ============ */

    /**
     * @notice Emitted when some yield is claim for `account` to `recipient`.
     * @param  account   The account under which yield was generated.
     * @param  recipient The account that received the yield.
     * @param  yield     The amount of yield claimed.
     */
    event Claimed(address indexed account, address indexed recipient, uint240 yield);

    /**
     * @notice Emitted when `account` starts being an wM earner.
     * @param  account       The account that started earning.
     * @param  nullifierHash The semaphore nullifier unique to a semaphore identity within this scope.
     */
    event StartedEarning(address indexed account, uint256 indexed nullifierHash);

    /**
     * @notice Emitted when `account` stops being an wM earner.
     * @param  account The account that stopped earning.
     */
    event StoppedEarning(address indexed account);

    /* ============ Custom Errors ============ */

    /**
     * @notice Emitted when there is insufficient balance to decrement from `account`.
     * @param  account The account with insufficient balance.
     * @param  balance The balance of the account.
     * @param  amount  The amount to decrement.
     */
    error InsufficientBalance(address account, uint240 balance, uint240 amount);

    /// @notice Emitted when the migrate function is called by a account other than the migration admin.
    error UnauthorizedMigration();

    /// @notice Emitted in an account is 0x0.
    error ZeroAccount();

    /// @notice Emitted in constructor if M Token is 0x0.
    error ZeroMToken();

    /// @notice Emitted in constructor if Migration Admin is 0x0.
    error ZeroMigrationAdmin();

    /// @notice Emitted in constructor if World ID Router is 0x0.
    error ZeroWorldIDRouter();

    /// @notice Emitted if the semaphore signal is invalid in the context it is being used.
    error UnauthorizedSignal();

    /// @notice Emitted if the semaphore nullifier is not associated to an account.
    error NullifierNotFound();

    /// @notice Emitted when trying to start earning for a second account using the same semaphore identity.
    error NullifierAlreadyUsed();

    /// @notice Emitted when trying to stop earning for an account using the incorrect semaphore identity.
    error NullifierMismatch();

    /// @notice Emitted when trying to start earning for an account that is already earning.
    error AlreadyEarning();

    /// @notice Emitted when trying to stop earning for an account that is already not earning.
    error AlreadyNotEarning();

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
     * @param  destination   The account to send the yield to.
     * @param  root          The merkle root of the semaphore group.
     * @param  groupId       The identifier of the World group.
     * @param  signalHash    The semaphore signal authorizing this action.
     * @param  nullifierHash The semaphore nullifier unique to a semaphore identity within this scope.
     * @return yield         The amount of yield claimed.
     */
    function claim(
        address destination,
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external returns (uint240 yield);

    /**
     * @notice Starts earning for the caller if a valid proof is provided by a verified World ID identity.
     * @param  root          The merkle root of the semaphore group.
     * @param  groupId       The identifier of the World group.
     * @param  signalHash    The semaphore signal authorizing this action.
     * @param  nullifierHash The semaphore nullifier unique to a semaphore identity within this scope.
     */
    function startEarning(
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external;

    /**
     * @notice Stops earning for `account` if a valid proof is provided by the associated verified World ID identity.
     * @param  root          The merkle root of the semaphore group.
     * @param  groupId       The identifier of the World group.
     * @param  signalHash    The semaphore signal authorizing this action.
     * @param  nullifierHash The semaphore nullifier unique to a semaphore identity within this scope.
     */
    function stopEarning(
        address account,
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external;

    /**
     * @notice Stops earning for the caller by disassociating the verified World ID identity.
     * @param  nullifierHash The semaphore nullifier unique to a semaphore identity within this scope.
     */
    function stopEarning(uint256 nullifierHash) external;

    /* ============ Temporary Admin Migration ============ */

    /**
     * @notice Performs an arbitrarily defined migration.
     * @param  migrator The address of a migrator contract.
     */
    function migrate(address migrator) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Prefix to validate semaphore signal to start earning.
    function START_EARNING_SIGNAL_PREFIX() external pure returns (bytes32 startEarningSignalPrefix);

    /// @notice Prefix to validate semaphore signal to stop earning.
    function STOP_EARNING_SIGNAL_PREFIX() external pure returns (bytes32 stopEarningSignalPrefix);

    /// @notice Prefix to validate semaphore signal to claim yield.
    function CLAIM_SIGNAL_PREFIX() external pure returns (bytes32 claimSignalPrefix);

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

    /// @notice The current index of Smart M's earning mechanism.
    function currentIndex() external view returns (uint128 index);

    /// @notice This contract's current excess M that is not earmarked for account balances or accrued yield.
    function excess() external view returns (uint240 excess);

    /// @notice Hash to validate semaphore scope, unique to this app and action.
    function externalNullifier() external view returns (uint256 externalNullifier);

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

    /// @notice The account that can call the `migrate(address migrator)` function.
    function migrationAdmin() external view returns (address migrationAdmin);

    /// @notice The address of the M Token contract.
    function mToken() external view returns (address mToken);

    /// @notice The portion of total supply that is not earning yield.
    function totalNonEarningSupply() external view returns (uint240 totalSupply);

    /// @notice The accrued yield of the portion of total supply that is earning yield.
    function totalAccruedYield() external view returns (uint240 yield);

    /// @notice The portion of total supply that is earning yield.
    function totalEarningSupply() external view returns (uint240 totalSupply);

    /// @notice The total earning principal to help compute totalAccruedYield(), and thus excess().
    function totalEarningPrincipal() external view returns (uint112 totalEarningPrincipal);

    /// @notice The address of the World ID Router to verify semaphore proofs with.
    function worldIDRouter() external view returns (address worldIDRouter);
}
