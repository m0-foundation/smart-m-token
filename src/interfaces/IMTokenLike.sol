// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/**
 * @title  Subset of M Token interface required for source contracts.
 * @author M^0 Labs
 */
interface IMTokenLike {
    /* ============ Interactive Functions ============ */

    /**
     * @notice Allows a calling account to transfer `amount` tokens to `recipient`.
     * @param  recipient The address of the recipient who's token balance will be incremented.
     * @param  amount    The amount of tokens being transferred.
     * @return success   Whether or not the transfer was successful.
     */
    function transfer(address recipient, uint256 amount) external returns (bool success);

    /**
     * @notice Allows a calling account to transfer `amount` tokens from `sender`, with allowance, to a `recipient`.
     * @param  sender    The address of the sender who's token balance will be decremented.
     * @param  recipient The address of the recipient who's token balance will be incremented.
     * @param  amount    The amount of tokens being transferred.
     * @return success   Whether or not the transfer was successful.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool success);

    /// @notice Starts earning for caller if allowed by the Registrar.
    function startEarning() external;

    /// @notice Stops earning for caller.
    function stopEarning() external;

    /* ============ View/Pure Functions ============ */

    /**
     * @notice Checks if account is an earner.
     * @param  account The account to check.
     * @return earning True if account is an earner, false otherwise.
     */
    function isEarning(address account) external view returns (bool earning);

    /**
     * @notice Returns the token balance of `account`.
     * @param  account The address of some account.
     * @return balance The token balance of `account`.
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /// @notice The current index that would be written to storage if `updateIndex` is called.
    function currentIndex() external view returns (uint128 currentIndex);
}
