// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { ERC20Extended } from "../lib/common/src/ERC20Extended.sol";

import { IndexingMath } from "./libs/IndexingMath.sol";

import { IEarnerManager } from "./interfaces/IEarnerManager.sol";
import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { IWrappedMToken } from "./interfaces/IWrappedMToken.sol";

import { Migratable } from "./Migratable.sol";

/*

██╗    ██╗██████╗  █████╗ ██████╗ ██████╗ ███████╗██████╗     ███╗   ███╗    ████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗
██║    ██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗    ████╗ ████║    ╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║
██║ █╗ ██║██████╔╝███████║██████╔╝██████╔╝█████╗  ██║  ██║    ██╔████╔██║       ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║
██║███╗██║██╔══██╗██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  ██║  ██║    ██║╚██╔╝██║       ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║
╚███╔███╔╝██║  ██║██║  ██║██║     ██║     ███████╗██████╔╝    ██║ ╚═╝ ██║       ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║
 ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝╚═════╝     ╚═╝     ╚═╝       ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝

*/

/**
 * @title  ERC20 Token contract for wrapping M into a non-rebasing token with claimable yields.
 * @author M^0 Labs
 */
contract WrappedMToken is IWrappedMToken, Migratable, ERC20Extended {
    /* ============ Structs ============ */

    /**
     * @dev   Struct to represent an account's balance and yield earning details
     * @param isEarning        Whether the account is actively earning yield.
     * @param balance          The present amount of tokens held by the account.
     * @param lastIndex        The index of the last interaction for the account (0 for non-earning accounts).
     * @param hasEarnerDetails Whether the account has additional details for earning yield.
     */
    struct Account {
        // First Slot
        bool isEarning;
        uint240 balance;
        // Second slot
        uint128 lastIndex;
        bool hasClaimRecipient;
        bool hasEarnerDetails
    }

    /* ============ Variables ============ */

    /// @inheritdoc IWrappedMToken
    uint16 public constant HUNDRED_PERCENT = 10_000;

    /// @inheritdoc IWrappedMToken
    bytes32 public constant EARNERS_LIST_IGNORED_KEY = "earners_list_ignored";

    /// @inheritdoc IWrappedMToken
    bytes32 public constant EARNERS_LIST_NAME = "earners";

    /// @inheritdoc IWrappedMToken
    bytes32 public constant CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX = "wm_claim_override_recipient";

    /// @inheritdoc IWrappedMToken
    bytes32 public constant MIGRATOR_KEY_PREFIX = "wm_migrator_v2";

    /// @inheritdoc IWrappedMToken
    address public immutable earnerManager;

    /// @inheritdoc IWrappedMToken
    address public immutable migrationAdmin;

    /// @inheritdoc IWrappedMToken
    address public immutable mToken;

    /// @inheritdoc IWrappedMToken
    address public immutable registrar;

    /// @inheritdoc IWrappedMToken
    address public immutable excessDestination;

    /// @inheritdoc IWrappedMToken
    uint112 public principalOfTotalEarningSupply;

    /// @inheritdoc IWrappedMToken
    uint240 public totalEarningSupply;

    /// @inheritdoc IWrappedMToken
    uint240 public totalNonEarningSupply;

    /// @dev Mapping of accounts to their respective `AccountInfo` structs.
    mapping(address account => Account balance) internal _accounts;

    /// @dev Array of indices at which earning was enabled or disabled.
    uint128[] internal _enableDisableEarningIndices;

    mapping(address account => address claimRecipient) internal _claimRecipients;

    /* ============ Constructor ============ */

    /**
     * @dev   Constructs the contract given an M Token address and migration admin.
     *        Note that a proxy will not need to initialize since there are no mutable storage values affected.
     * @param mToken_            The address of an M Token.
     * @param registrar_         The address of a Registrar.
     * @param earnerManager_     The address of an Earner Manager.
     * @param excessDestination_ The address of an excess destination.
     * @param migrationAdmin_    The address of a migration admin.
     */
    constructor(
        address mToken_,
        address registrar_,
        address earnerManager_,
        address excessDestination_,
        address migrationAdmin_
    ) ERC20Extended("M by M^0 (wrapped)", "wM", 6) {
        if ((mToken = mToken_) == address(0)) revert ZeroMToken();
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
        if ((earnerManager = earnerManager_) == address(0)) revert ZeroEarnerManager();
        if ((excessDestination = excessDestination_) == address(0)) revert ZeroExcessDestination();
        if ((migrationAdmin = migrationAdmin_) == address(0)) revert ZeroMigrationAdmin();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IWrappedMToken
    function wrap(address recipient_, uint256 amount_) external returns (uint240 wrapped_) {
        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWrappedMToken
    function wrap(address recipient_) external returns (uint240 wrapped_) {
        return _wrap(msg.sender, recipient_, UIntMath.safe240(IMTokenLike(mToken).balanceOf(msg.sender)));
    }

    /// @inheritdoc IWrappedMToken
    function wrapWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint240 wrapped_) {
        IMTokenLike(mToken).permit(msg.sender, address(this), amount_, deadline_, v_, r_, s_);

        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWrappedMToken
    function wrapWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint240 wrapped_) {
        IMTokenLike(mToken).permit(msg.sender, address(this), amount_, deadline_, signature_);

        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWrappedMToken
    function unwrap(address recipient_, uint256 amount_) external returns (uint240 unwrapped_) {
        return _unwrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWrappedMToken
    function unwrap(address recipient_) external returns (uint240 unwrapped_) {
        return _unwrap(msg.sender, recipient_, uint240(balanceWithYieldOf(msg.sender)));
    }

    /// @inheritdoc IWrappedMToken
    function claimFor(address account_) external returns (uint240 yield_) {
        return _claim(account_, currentIndex());
    }

    /// @inheritdoc IWrappedMToken
    function claimExcess() external returns (uint240 excess_) {
        emit ExcessClaimed(excess_ = excess());

        IMTokenLike(mToken).transfer(excessDestination, excess_);
    }

    /// @inheritdoc IWrappedMToken
    function enableEarning() external {
        if (!_isThisApprovedEarner()) revert NotApprovedEarner(address(this));
        if (isEarningEnabled()) revert EarningIsEnabled();

        // NOTE: This is a temporary measure to prevent re-enabling earning after it has been disabled.
        //       This line will be removed in the future.
        if (wasEarningEnabled()) revert EarningCannotBeReenabled();

        uint128 currentMIndex_ = _currentMIndex();

        _enableDisableEarningIndices.push(currentMIndex_);

        IMTokenLike(mToken).startEarning();

        emit EarningEnabled(currentMIndex_);
    }

    /// @inheritdoc IWrappedMToken
    function disableEarning() external {
        if (_isThisApprovedEarner()) revert IsApprovedEarner(address(this));
        if (!isEarningEnabled()) revert EarningIsDisabled();

        uint128 currentMIndex_ = _currentMIndex();

        _enableDisableEarningIndices.push(currentMIndex_);

        IMTokenLike(mToken).stopEarning();

        emit EarningDisabled(currentMIndex_);
    }

    /// @inheritdoc IWrappedMToken
    function startEarningFor(address account_) external {
        if (!isEarningEnabled()) revert EarningIsDisabled();

        // NOTE: Use `currentIndex()` if/when upgrading to support `startEarningFor` while earning is disabled.
        _startEarningFor(account_, _currentMIndex());
    }

    /// @inheritdoc IWrappedMToken
    function startEarningFor(address[] calldata accounts_) external {
        if (!isEarningEnabled()) revert EarningIsDisabled();

        uint128 currentIndex_ = _currentMIndex();

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            _startEarningFor(accounts_[index_], currentIndex_);
        }
    }

    /// @inheritdoc IWrappedMToken
    function stopEarningFor(address account_) external {
        _stopEarningFor(account_, currentIndex());
    }

    /// @inheritdoc IWrappedMToken
    function stopEarningFor(address[] calldata accounts_) external {
        uint128 currentIndex_ = currentIndex();

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            _stopEarningFor(accounts_[index_], currentIndex_);
        }
    }

    /// @inheritdoc IWrappedMToken
    function setClaimRecipient(address claimRecipient_) external {
        _accounts[msg.sender].hasClaimRecipient = (_claimRecipients[msg.sender] = claimRecipient_) != address(0);

        emit ClaimRecipientSet(msg.sender, claimRecipient_);
    }

    /* ============ Temporary Admin Migration ============ */

    /// @inheritdoc IWrappedMToken
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IWrappedMToken
    function accruedYieldOf(address account_) public view returns (uint240 yield_) {
        Account storage accountInfo_ = _accounts[account_];

        return
            accountInfo_.isEarning ? _getAccruedYield(accountInfo_.balance, accountInfo_.lastIndex, currentIndex()) : 0;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account_) public view returns (uint256 balance_) {
        return _accounts[account_].balance;
    }

    /// @inheritdoc IWrappedMToken
    function balanceWithYieldOf(address account_) public view returns (uint256 balance_) {
        return balanceOf(account_) + accruedYieldOf(account_);
    }

    /// @inheritdoc IWrappedMToken
    function lastIndexOf(address account_) public view returns (uint128 lastIndex_) {
        return _accounts[account_].lastIndex;
    }

    /// @inheritdoc IWrappedMToken
    function claimRecipientFor(address account_) public view returns (address recipient_) {
        return
            (_accounts[account_].hasClaimRecipient)
                ? _claimRecipients[account_]
                : address(
                    uint160(
                        uint256(
                            IRegistrarLike(registrar).get(
                                keccak256(abi.encode(CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, account_))
                            )
                        )
                    )
                );
    }

    /// @inheritdoc IWrappedMToken
    function currentIndex() public view returns (uint128 index_) {
        return isEarningEnabled() ? _currentMIndex() : _lastDisableEarningIndex();
    }

    /// @inheritdoc IWrappedMToken
    function isEarning(address account_) external view returns (bool isEarning_) {
        return _accounts[account_].isEarning;
    }

    /// @inheritdoc IWrappedMToken
    function isEarningEnabled() public view returns (bool isEnabled_) {
        return _enableDisableEarningIndices.length % 2 == 1;
    }

    /// @inheritdoc IWrappedMToken
    function wasEarningEnabled() public view returns (bool wasEarning_) {
        return _enableDisableEarningIndices.length != 0;
    }

    /// @inheritdoc IWrappedMToken
    function excess() public view returns (uint240 excess_) {
        unchecked {
            uint128 currentIndex_ = currentIndex();
            uint240 balance_ = uint240(IMTokenLike(mToken).balanceOf(address(this)));
            uint240 earmarked_ = totalNonEarningSupply + _projectedEarningSupply(currentIndex_);

            return balance_ > earmarked_ ? _getSafeTransferableM(balance_ - earmarked_, currentIndex_) : 0;
        }
    }

    /// @inheritdoc IWrappedMToken
    function totalAccruedYield() external view returns (uint240 yield_) {
        unchecked {
            uint240 projectedEarningSupply_ = _projectedEarningSupply(currentIndex());
            uint240 earningSupply_ = totalEarningSupply;

            return projectedEarningSupply_ <= earningSupply_ ? 0 : projectedEarningSupply_ - earningSupply_;
        }
    }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256 totalSupply_) {
        return totalEarningSupply + totalNonEarningSupply;
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Mints `amount_` tokens to `recipient_`.
     * @param recipient_ The address whose account balance will be incremented.
     * @param amount_    The present amount of tokens to mint.
     */
    function _mint(address recipient_, uint240 amount_) internal {
        _revertIfInsufficientAmount(amount_);
        _revertIfZeroAccount(recipient_);

        if (_accounts[recipient_].isEarning) {
            uint128 currentIndex_ = currentIndex();

            _claim(recipient_, currentIndex_);

            // NOTE: Additional principal may end up being rounded to 0 and this will not `_revertIfInsufficientAmount`.
            _addEarningAmount(recipient_, amount_, currentIndex_);
        } else {
            _addNonEarningAmount(recipient_, amount_);
        }

        emit Transfer(address(0), recipient_, amount_);
    }

    /**
     * @dev   Burns `amount_` tokens from `account_`.
     * @param account_ The address whose account balance will be decremented.
     * @param amount_  The present amount of tokens to burn.
     */
    function _burn(address account_, uint240 amount_) internal {
        _revertIfInsufficientAmount(amount_);

        if (_accounts[account_].isEarning) {
            uint128 currentIndex_ = currentIndex();

            _claim(account_, currentIndex_);

            // NOTE: Subtracted principal may end up being rounded to 0 and this will not `_revertIfInsufficientAmount`.
            _subtractEarningAmount(account_, amount_, currentIndex_);
        } else {
            _subtractNonEarningAmount(account_, amount_);
        }

        emit Transfer(account_, address(0), amount_);
    }

    /**
     * @dev   Increments the token balance of `account_` by `amount_`, assuming non-earning status.
     * @param account_ The address whose account balance will be incremented.
     * @param amount_  The present amount of tokens to increment by.
     */
    function _addNonEarningAmount(address account_, uint240 amount_) internal {
        // NOTE: Can be `unchecked` because the max amount of wrappable M is never greater than `type(uint240).max`.
        unchecked {
            _accounts[account_].balance += amount_;
            totalNonEarningSupply += amount_;
        }
    }

    /**
     * @dev   Decrements the token balance of `account_` by `amount_`, assuming non-earning status.
     * @param account_ The address whose account balance will be decremented.
     * @param amount_  The present amount of tokens to decrement by.
     */
    function _subtractNonEarningAmount(address account_, uint240 amount_) internal {
        unchecked {
            Account storage accountInfo_ = _accounts[account_];

            uint240 balance_ = accountInfo_.balance;

            if (balance_ < amount_) revert InsufficientBalance(account_, balance_, amount_);

            accountInfo_.balance = balance_ - amount_;
            totalNonEarningSupply -= amount_;
        }
    }

    /**
     * @dev   Increments the token balance of `account_` by `amount_`, assuming earning status and updated index.
     * @param account_      The address whose account balance will be incremented.
     * @param amount_       The present amount of tokens to increment by.
     * @param currentIndex_ The current index to use to compute the principal amount.
     */
    function _addEarningAmount(address account_, uint240 amount_, uint128 currentIndex_) internal {
        // NOTE: Can be `unchecked` because the max amount of wrappable M is never greater than `type(uint240).max`.
        unchecked {
            _accounts[account_].balance += amount_;
            _addTotalEarningSupply(amount_, currentIndex_);
        }
    }

    /**
     * @dev   Decrements the token balance of `account_` by `amount_`, assuming earning status and updated index.
     * @param account_      The address whose account balance will be decremented.
     * @param amount_       The present amount of tokens to decrement by.
     * @param currentIndex_ The current index to use to compute the principal amount.
     */
    function _subtractEarningAmount(address account_, uint240 amount_, uint128 currentIndex_) internal {
        unchecked {
            Account storage accountInfo_ = _accounts[account_];

            uint240 balance_ = accountInfo_.balance;

            if (balance_ < amount_) revert InsufficientBalance(account_, balance_, amount_);

            accountInfo_.balance = balance_ - amount_;
            _subtractTotalEarningSupply(amount_, currentIndex_);
        }
    }

    /**
     * @dev    Claims accrued yield for `account_` given a `currentIndex_`.
     * @param  account_      The address to claim accrued yield for.
     * @param  currentIndex_ The current index to accrue until.
     * @return yield_        The accrued yield that was claimed.
     */
    function _claim(address account_, uint128 currentIndex_) internal returns (uint240 yield_) {
        Account storage accountInfo_ = _accounts[account_];

        if (!accountInfo_.isEarning) return 0;

        uint128 index_ = accountInfo_.lastIndex;

        if (currentIndex_ == index_) return 0;

        uint240 startingBalance_ = accountInfo_.balance;

        yield_ = _getAccruedYield(startingBalance_, index_, currentIndex_);

        accountInfo_.lastIndex = currentIndex_;

        if (yield_ == 0) return 0;

        unchecked {
            accountInfo_.balance = startingBalance_ + yield_;

            // Update the total earning supply to account for the yield, but the principal has not changed.
            totalEarningSupply += yield_;
        }

        address claimOverrideRecipient_ = claimRecipientFor(account_);
        address claimRecipient_ = claimOverrideRecipient_ == address(0) ? account_ : claimOverrideRecipient_;

        // Emit the appropriate `Claimed` and `Transfer` events, depending on the claim override recipient
        emit Claimed(account_, claimRecipient_, yield_);
        emit Transfer(address(0), account_, yield_);

        uint240 yieldNetOfFees_ = yield_;

        if (accountInfo_.hasEarnerDetails) {
            unchecked {
                yieldNetOfFees_ -= _handleEarnerDetails(account_, yield_, currentIndex_);
            }
        }

        if ((claimRecipient_ != account_) && (yieldNetOfFees_ != 0)) {
            // NOTE: Watch out for a long chain of earning claim override recipients.
            _transfer(account_, claimRecipient_, yieldNetOfFees_, currentIndex_);
        }
    }

    /**
     * @dev    Handles the computation and transfer of fees to the admin of an account with earner details.
     * @param  account_      The address of the account to handle earner details for.
     * @param  yield_        The yield accrued by the account.
     * @param  currentIndex_ The current index to use to compute the principal amount.
     * @return fee_          The fee amount that was transferred to the admin.
     */
    function _handleEarnerDetails(
        address account_,
        uint240 yield_,
        uint128 currentIndex_
    ) internal returns (uint240 fee_) {
        (, uint16 feeRate_, address admin_) = IEarnerManager(earnerManager).getEarnerDetails(account_);

        if (admin_ == address(0)) {
            // Prevent transferring to address(0) and remove `hasEarnerDetails` property going forward.
            _accounts[account_].hasEarnerDetails = false;
            return 0;
        }

        if (feeRate_ == 0) return 0;

        feeRate_ = feeRate_ > HUNDRED_PERCENT ? HUNDRED_PERCENT : feeRate_; // Ensure fee rate is capped at 100%.

        unchecked {
            fee_ = (feeRate_ * yield_) / HUNDRED_PERCENT;
        }

        if (fee_ == 0) return 0;

        _transfer(account_, admin_, fee_, currentIndex_);
    }

    /**
     * @dev   Transfers `amount_` tokens from `sender_` to `recipient_` given some current index.
     * @param sender_       The sender's address.
     * @param recipient_    The recipient's address.
     * @param amount_       The amount to be transferred.
     * @param currentIndex_ The current index.
     */
    function _transfer(address sender_, address recipient_, uint240 amount_, uint128 currentIndex_) internal {
        _revertIfZeroAccount(sender_);
        _revertIfZeroAccount(recipient_);

        // Claims for both the sender and recipient are required before transferring since add an subtract functions
        // assume accounts' balances are up-to-date with the current index.
        _claim(sender_, currentIndex_);
        _claim(recipient_, currentIndex_);

        emit Transfer(sender_, recipient_, amount_);

        if (amount_ == 0) return;

        Account storage senderAccountInfo_ = _accounts[sender_];
        Account storage recipientAccountInfo_ = _accounts[recipient_];

        // If the sender and recipient are both earning or both non-earning, update their balances without affecting
        // the total earning and non-earning supply storage variables.
        if (senderAccountInfo_.isEarning == recipientAccountInfo_.isEarning) {
            uint240 senderBalance_ = senderAccountInfo_.balance;

            if (senderBalance_ < amount_) revert InsufficientBalance(sender_, senderBalance_, amount_);

            unchecked {
                senderAccountInfo_.balance = senderBalance_ - amount_;
                recipientAccountInfo_.balance += amount_;
            }

            return;
        }

        senderAccountInfo_.isEarning
            ? _subtractEarningAmount(sender_, amount_, currentIndex_)
            : _subtractNonEarningAmount(sender_, amount_);

        recipientAccountInfo_.isEarning
            ? _addEarningAmount(recipient_, amount_, currentIndex_)
            : _addNonEarningAmount(recipient_, amount_);
    }

    /**
     * @dev   Internal ERC20 transfer function that needs to be implemented by the inheriting contract.
     * @param sender_    The sender's address.
     * @param recipient_ The recipient's address.
     * @param amount_    The amount to be transferred.
     */
    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        _transfer(sender_, recipient_, UIntMath.safe240(amount_), currentIndex());
    }

    /**
     * @dev   Increments total earning supply by `amount_` tokens.
     * @param amount_       The present amount of tokens to increment total earning supply by.
     * @param currentIndex_ The current index used to compute the principal amount.
     */
    function _addTotalEarningSupply(uint240 amount_, uint128 currentIndex_) internal {
        unchecked {
            // Increment the total earning supply and principal proportionally.
            totalEarningSupply += amount_;
            principalOfTotalEarningSupply += IndexingMath.getPrincipalAmountRoundedUp(amount_, currentIndex_);
        }
    }

    /**
     * @dev   Decrements total earning supply by `amount_` tokens.
     * @param amount_       The present amount of tokens to decrement total earning supply by.
     * @param currentIndex_ The current index used to compute the principal amount.
     */
    function _subtractTotalEarningSupply(uint240 amount_, uint128 currentIndex_) internal {
        if (amount_ >= totalEarningSupply) {
            delete totalEarningSupply;
            delete principalOfTotalEarningSupply;

            return;
        }

        unchecked {
            uint112 principal_ = IndexingMath.getPrincipalAmountRoundedDown(amount_, currentIndex_);

            principalOfTotalEarningSupply -= (
                principal_ > principalOfTotalEarningSupply ? principalOfTotalEarningSupply : principal_
            );

            totalEarningSupply -= amount_;
        }
    }

    /**
     * @dev    Wraps `amount` M from `account_` into wM for `recipient`.
     * @param  account_   The account from which M is deposited.
     * @param  recipient_ The account receiving the minted wM.
     * @param  amount_    The amount of M deposited.
     * @return wrapped_   The amount of wM minted.
     */
    function _wrap(address account_, address recipient_, uint240 amount_) internal returns (uint240 wrapped_) {
        uint256 startingBalance_ = IMTokenLike(mToken).balanceOf(address(this));

        // NOTE: The behavior of `IMTokenLike.transferFrom` is known, so its return can be ignored.
        IMTokenLike(mToken).transferFrom(account_, address(this), amount_);

        // NOTE: When this WrappedMToken contract is earning, any amount of M sent to it is converted to a principal
        //       amount at the MToken contract, which when represented as a present amount, may be a rounding error
        //       amount less than `amount_`. In order to capture the real increase in M, the difference between the
        //       starting and ending M balance is minted as WrappedM.
        _mint(recipient_, wrapped_ = UIntMath.safe240(IMTokenLike(mToken).balanceOf(address(this)) - startingBalance_));
    }

    /**
     * @dev    Unwraps `amount` wM from `account_` into M for `recipient`.
     * @param  account_   The account from which WM is burned.
     * @param  recipient_ The account receiving the withdrawn M.
     * @param  amount_    The amount of wM burned.
     * @return unwrapped_ The amount of M withdrawn.
     */
    function _unwrap(address account_, address recipient_, uint240 amount_) internal returns (uint240 unwrapped_) {
        _burn(account_, amount_);

        uint256 startingBalance_ = IMTokenLike(mToken).balanceOf(address(this));

        // NOTE: The behavior of `IMTokenLike.transfer` is known, so its return can be ignored.
        IMTokenLike(mToken).transfer(recipient_, _getSafeTransferableM(amount_, currentIndex()));

        // NOTE: When this WrappedMToken contract is earning, any amount of M sent from it is converted to a principal
        //       amount at the MToken contract, which when represented as a present amount, may be a rounding error
        //       amount more than `amount_`. In order to capture the real decrease in M, the difference between the
        //       ending and starting M balance is returned.
        return UIntMath.safe240(startingBalance_ - IMTokenLike(mToken).balanceOf(address(this)));
    }

    /**
     * @dev   Starts earning for `account` if allowed by the Registrar.
     * @param account_      The account to start earning for.
     * @param currentIndex_ The current index.
     */
    function _startEarningFor(address account_, uint128 currentIndex_) internal {
        (bool isEarner_, , address admin_) = IEarnerManager(earnerManager).getEarnerDetails(account_);

        if (!isEarner_) revert NotApprovedEarner(account_);

        Account storage accountInfo_ = _accounts[account_];

        if (accountInfo_.isEarning) return;

        accountInfo_.isEarning = true;
        accountInfo_.lastIndex = currentIndex_;
        accountInfo_.hasEarnerDetails = admin_ != address(0); // Has earner details if an admin exists for this account.

        uint240 balance_ = accountInfo_.balance;

        _addTotalEarningSupply(balance_, currentIndex_);

        unchecked {
            totalNonEarningSupply -= balance_;
        }

        emit StartedEarning(account_);
    }

    /**
     * @dev   Stops earning for `account` if disallowed by the Registrar.
     * @param account_      The account to stop earning for.
     * @param currentIndex_ The current index.
     */
    function _stopEarningFor(address account_, uint128 currentIndex_) internal {
        (bool isEarner_, , ) = IEarnerManager(earnerManager).getEarnerDetails(account_);

        if (isEarner_) revert IsApprovedEarner(account_);

        _claim(account_, currentIndex_);

        Account storage accountInfo_ = _accounts[account_];

        if (!accountInfo_.isEarning) return;

        delete accountInfo_.isEarning;
        delete accountInfo_.lastIndex;
        delete accountInfo_.hasEarnerDetails;

        uint240 balance_ = accountInfo_.balance;

        _subtractTotalEarningSupply(balance_, currentIndex_);

        unchecked {
            totalNonEarningSupply += balance_;
        }

        emit StoppedEarning(account_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the current index of the M Token.
    function _currentMIndex() internal view returns (uint128 index_) {
        return IMTokenLike(mToken).currentIndex();
    }

    /// @dev Returns whether this contract is a Registrar-approved earner.
    function _isThisApprovedEarner() internal view returns (bool) {
        return
            IRegistrarLike(registrar).get(EARNERS_LIST_IGNORED_KEY) != bytes32(0) ||
            IRegistrarLike(registrar).listContains(EARNERS_LIST_NAME, address(this));
    }

    /// @dev Returns the earning index from the last `disableEarning` call.
    function _lastDisableEarningIndex() internal view returns (uint128 index_) {
        return wasEarningEnabled() ? _unsafeAccess(_enableDisableEarningIndices, 1) : 0;
    }

    /**
     * @dev    Compute the yield given an account's balance, last index, and the current index.
     * @param  balance_      The token balance of an earning account.
     * @param  lastIndex_    The index of ast interaction for the account.
     * @param  currentIndex_ The current index.
     * @return yield_        The yield accrued since the last interaction.
     */
    function _getAccruedYield(
        uint240 balance_,
        uint128 lastIndex_,
        uint128 currentIndex_
    ) internal pure returns (uint240 yield_) {
        uint240 balanceWithYield_ = IndexingMath.getPresentAmountRoundedDown(
            IndexingMath.getPrincipalAmountRoundedDown(balance_, lastIndex_),
            currentIndex_
        );

        unchecked {
            return (balanceWithYield_ <= balance_) ? 0 : balanceWithYield_ - balance_;
        }
    }

    /**
     * @dev    Compute the adjusted amount of M that can safely be transferred out given the current index.
     * @param  amount_       Some amount to be transferred out of the wrapper.
     * @param  currentIndex_ The current index.
     * @return safeAmount_   The adjusted amount that can safely be transferred out.
     */
    function _getSafeTransferableM(uint240 amount_, uint128 currentIndex_) internal view returns (uint240 safeAmount_) {
        // If the wrapper is earning, adjust `amount_` to ensure it's M balance decrement is limited to `amount_`.
        return
            IMTokenLike(mToken).isEarning(address(this))
                ? IndexingMath.getPresentAmountRoundedDown(
                    IndexingMath.getPrincipalAmountRoundedDown(amount_, currentIndex_),
                    currentIndex_
                )
                : amount_;
    }

    /// @dev Returns the address of the contract to use as a migrator, if any.
    function _getMigrator() internal view override returns (address migrator_) {
        return
            address(
                uint160(
                    // NOTE: A subsequent implementation should use a unique migrator prefix.
                    uint256(IRegistrarLike(registrar).get(keccak256(abi.encode(MIGRATOR_KEY_PREFIX, address(this)))))
                )
            );
    }

    /**
     * @dev    Returns the projected total earning supply if all accrued yield was claimed at this moment.
     * @param  currentIndex_ The current index.
     * @return supply_       The projected total earning supply.
     */
    function _projectedEarningSupply(uint128 currentIndex_) internal view returns (uint240 supply_) {
        return IndexingMath.getPresentAmountRoundedDown(principalOfTotalEarningSupply, currentIndex_);
    }

    /**
     * @dev   Reverts if `amount_` is equal to 0.
     * @param amount_ Amount of token.
     */
    function _revertIfInsufficientAmount(uint256 amount_) internal pure {
        if (amount_ == 0) revert InsufficientAmount(amount_);
    }

    /**
     * @dev   Reverts if `account_` is address(0).
     * @param account_ Address of an account.
     */
    function _revertIfZeroAccount(address account_) internal pure {
        if (account_ == address(0)) revert ZeroAccount();
    }

    /**
     * @dev   Reads the uint128 value at some index of an array of uint128 values whose storage pointer is given,
     *        assuming the index is valid, without wasting gas checking for out-of-bounds errors.
     * @param array_ The storage pointer of an array of uint128 values.
     * @param i_     The index of the array to read.
     */
    function _unsafeAccess(uint128[] storage array_, uint256 i_) internal view returns (uint128 value_) {
        assembly {
            mstore(0, array_.slot)

            value_ := sload(add(keccak256(0, 0x20), div(i_, 2)))

            // Since uint128 values take up either the top half or bottom half of a slot, shift the result accordingly.
            if eq(mod(i_, 2), 1) {
                value_ := shr(128, value_)
            }
        }
    }
}
