// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";
import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { ERC20Extended } from "../lib/common/src/ERC20Extended.sol";

import { Migratable } from "../lib/common/src/Migratable.sol";

import { IEarnerManager } from "./interfaces/IEarnerManager.sol";
import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { ISmartMToken } from "./interfaces/ISmartMToken.sol";
import { IWorldIDRouterLike } from "./interfaces/IWorldIDRouterLike.sol";

/*

███████╗███╗   ███╗ █████╗ ██████╗ ████████╗    ███╗   ███╗    ████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗
██╔════╝████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝    ████╗ ████║    ╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║
███████╗██╔████╔██║███████║██████╔╝   ██║       ██╔████╔██║       ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║
╚════██║██║╚██╔╝██║██╔══██║██╔══██╗   ██║       ██║╚██╔╝██║       ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║
███████║██║ ╚═╝ ██║██║  ██║██║  ██║   ██║       ██║ ╚═╝ ██║       ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝       ╚═╝     ╚═╝       ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝

*/

/**
 * @title  ERC20 Token contract for wrapping M into a non-rebasing token with claimable yields.
 * @author M^0 Labs
 */
contract SmartMToken is ISmartMToken, Migratable, ERC20Extended {
    /* ============ Structs ============ */

    /**
     * @dev   Struct to represent an account's balance and yield earning details.
     * @param isEarning         Whether the account is actively earning yield.
     * @param balance           The present amount of tokens held by the account.
     * @param version           The version of the Account struct.
     * @param earningPrincipal  The earning principal for the account (0 for non-earning accounts).
     * @param hasEarnerDetails  Whether the account has additional details for earning yield.
     * @param hasClaimRecipient Whether the account has an explicitly set claim recipient.
     */
    struct Account {
        // First Slot
        bool isEarning;
        uint240 balance;
        uint8 version;
        // Second slot
        uint112 earningPrincipal;
        bool hasEarnerDetails;
        bool hasClaimRecipient;
        bool hasNullifier;
    }

    /**
     * @dev   Struct to track a semaphore nullifier's usage.
     * @param account The account, if any, the nullifier hash is currently used to enable earning for.
     * @param nonce   The next expected signal nonce for this nullifier hash, to prevent signal replays.
     */
    struct Nullifier {
        address account;
        uint96 nonce;
    }

    /* ============ Variables ============ */

    /// @inheritdoc ISmartMToken
    uint16 public constant HUNDRED_PERCENT = 10_000;

    /// @inheritdoc ISmartMToken
    bytes32 public constant EARNERS_LIST_IGNORED_KEY = "earners_list_ignored";

    /// @inheritdoc ISmartMToken
    bytes32 public constant EARNERS_LIST_NAME = "earners";

    /// @inheritdoc ISmartMToken
    bytes32 public constant CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX = "wm_claim_override_recipient";

    /// @inheritdoc ISmartMToken
    bytes32 public constant MIGRATOR_KEY_PREFIX = "wm_migrator_v3";

    /// @inheritdoc ISmartMToken
    bytes32 public constant START_EARNING_SIGNAL_PREFIX = "start_earning";

    /// @inheritdoc ISmartMToken
    bytes32 public constant STOP_EARNING_SIGNAL_PREFIX = "stop_earning";

    /// @inheritdoc ISmartMToken
    bytes32 public constant CLAIM_SIGNAL_PREFIX = "claim";

    /// @inheritdoc ISmartMToken
    uint256 public constant EXTERNAL_NULLIFIER_HASH = uint256(keccak256("TODO"));

    /// @inheritdoc ISmartMToken
    address public immutable earnerManager;

    /// @inheritdoc ISmartMToken
    address public immutable migrationAdmin;

    /// @inheritdoc ISmartMToken
    address public immutable mToken;

    /// @inheritdoc ISmartMToken
    address public immutable registrar;

    /// @inheritdoc ISmartMToken
    address public immutable excessDestination;

    /// @inheritdoc ISmartMToken
    address public immutable worldIDRouter;

    /// @inheritdoc ISmartMToken
    uint112 public totalEarningPrincipal;

    /// @inheritdoc ISmartMToken
    uint240 public totalEarningSupply;

    /// @inheritdoc ISmartMToken
    uint240 public totalNonEarningSupply;

    /// @dev Mapping of accounts to their respective `AccountInfo` structs.
    mapping(address account => Account balance) internal _accounts;

    /// @inheritdoc ISmartMToken
    uint128 public enableMIndex;

    /// @inheritdoc ISmartMToken
    uint128 public disableIndex;

    mapping(address account => address claimRecipient) internal _claimRecipients;

    mapping(uint256 nullifierHash => Nullifier nullifier) internal _nullifiers;

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
        address migrationAdmin_,
        address worldIDRouter_
    ) ERC20Extended("Smart M by M^0", "MSMART", 6) {
        if ((mToken = mToken_) == address(0)) revert ZeroMToken();
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
        if ((earnerManager = earnerManager_) == address(0)) revert ZeroEarnerManager();
        if ((excessDestination = excessDestination_) == address(0)) revert ZeroExcessDestination();
        if ((migrationAdmin = migrationAdmin_) == address(0)) revert ZeroMigrationAdmin();
        if ((worldIDRouter = worldIDRouter_) == address(0)) revert ZeroWorldIDRouter();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISmartMToken
    function wrap(address recipient_, uint256 amount_) external returns (uint240 wrapped_) {
        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc ISmartMToken
    function wrap(address recipient_) external returns (uint240 wrapped_) {
        return _wrap(msg.sender, recipient_, UIntMath.safe240(_getMBalanceOf(msg.sender)));
    }

    /// @inheritdoc ISmartMToken
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

    /// @inheritdoc ISmartMToken
    function wrapWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint240 wrapped_) {
        IMTokenLike(mToken).permit(msg.sender, address(this), amount_, deadline_, signature_);

        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc ISmartMToken
    function unwrap(address recipient_, uint256 amount_) external returns (uint240 unwrapped_) {
        return _unwrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc ISmartMToken
    function unwrap(address recipient_) external returns (uint240 unwrapped_) {
        return _unwrap(msg.sender, recipient_, uint240(balanceOf(msg.sender)));
    }

    /// @inheritdoc ISmartMToken
    function claimWithProof(
        address destination_,
        uint256 root_,
        uint256 groupId_,
        uint256 signalHash_,
        uint256 nullifierHash_,
        uint256 externalNullifierHash_,
        uint256[8] calldata proof_
    ) external returns (uint240 yield_) {
        _revertIfInvalidExternalNullifierHash(externalNullifierHash_);

        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        if (signalHash_ != uint256(keccak256(abi.encode(CLAIM_SIGNAL_PREFIX, nullifier_.nonce++, destination_)))) {
            revert UnauthorizedSignal();
        }

        address account_ = nullifier_.account;

        if (account_ == address(0)) revert NullifierNotFound();

        _verifySemaphoreProof(root_, groupId_, signalHash_, nullifierHash_, externalNullifierHash_, proof_);

        return _claim(account_, destination_);
    }

    /// @inheritdoc ISmartMToken
    function claim(address destination_) external returns (uint240 yield_) {
        _revertIfHasAssociatedNullifier(msg.sender);

        return _claim(msg.sender, destination_);
    }

    /// @inheritdoc ISmartMToken
    function claimFor(address account_) external returns (uint240 yield_) {
        _revertIfHasAssociatedNullifier(account_);

        address claimRecipient_ = claimRecipientFor(account_);

        return _claim(account_, claimRecipient_ == address(0) ? account_ : claimRecipient_);
    }

    /// @inheritdoc ISmartMToken
    function claimExcess() external returns (uint240 excess_) {
        emit ExcessClaimed(excess_ = excess());

        _transferM(excessDestination, excess_);
    }

    /// @inheritdoc ISmartMToken
    function enableEarning() external {
        if (!_isThisApprovedEarner()) revert NotApprovedEarner(address(this));
        if (isEarningEnabled()) revert EarningIsEnabled();

        emit EarningEnabled(enableMIndex = _currentMIndex());

        IMTokenLike(mToken).startEarning();
    }

    /// @inheritdoc ISmartMToken
    function disableEarning() external {
        if (_isThisApprovedEarner()) revert IsApprovedEarner(address(this));
        if (!isEarningEnabled()) revert EarningIsDisabled();

        emit EarningDisabled(disableIndex = currentIndex());

        delete enableMIndex;

        IMTokenLike(mToken).stopEarning();
    }

    /// @inheritdoc ISmartMToken
    function startEarningWithProof(
        uint256 root_,
        uint256 groupId_,
        uint256 signalHash_,
        uint256 nullifierHash_,
        uint256 externalNullifierHash_,
        uint256[8] calldata proof_
    ) external {
        _revertIfInvalidExternalNullifierHash(externalNullifierHash_);

        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        if (
            signalHash_ != uint256(keccak256(abi.encode(START_EARNING_SIGNAL_PREFIX, nullifier_.nonce++, msg.sender)))
        ) {
            revert UnauthorizedSignal();
        }

        if (nullifier_.account != address(0)) revert NullifierAlreadyUsed();

        nullifier_.account = msg.sender;

        _startEarning(msg.sender, currentIndex());

        _accounts[msg.sender].hasNullifier = true;

        _verifySemaphoreProof(root_, groupId_, signalHash_, nullifierHash_, externalNullifierHash_, proof_);
    }

    /// @inheritdoc ISmartMToken
    function startEarningFor(address account_) external {
        _startEarningIfApproved(account_, currentIndex());
    }

    /// @inheritdoc ISmartMToken
    function startEarningFor(address[] calldata accounts_) external {
        uint128 currentIndex_ = currentIndex();

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            _startEarningIfApproved(accounts_[index_], currentIndex_);
        }
    }

    /// @inheritdoc ISmartMToken
    function stopEarningWithProof(
        address account_,
        uint256 root_,
        uint256 groupId_,
        uint256 signalHash_,
        uint256 nullifierHash_,
        uint256 externalNullifierHash_,
        uint256[8] calldata proof_
    ) external {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        _revertIfInvalidExternalNullifierHash(externalNullifierHash_);
        _revertIfNullifierAccountMismatch(nullifier_.account, account_);

        if (signalHash_ != uint256(keccak256(abi.encode(STOP_EARNING_SIGNAL_PREFIX, nullifier_.nonce++, account_)))) {
            revert UnauthorizedSignal();
        }

        _stopEarning(account_);

        delete nullifier_.account;

        _verifySemaphoreProof(root_, groupId_, signalHash_, nullifierHash_, externalNullifierHash_, proof_);
    }

    /// @inheritdoc ISmartMToken
    function stopEarning(uint256 nullifierHash_) external {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        _revertIfNullifierAccountMismatch(nullifier_.account, msg.sender);

        delete nullifier_.account;

        _stopEarning(msg.sender);
    }

    /// @inheritdoc ISmartMToken
    function stopEarning() external {
        _revertIfHasAssociatedNullifier(msg.sender);
        _stopEarning(msg.sender);
    }

    /// @inheritdoc ISmartMToken
    function stopEarningFor(address account_) public {
        _revertIfHasAssociatedNullifier(account_);
        _stopEarningIfNotApproved(account_);
    }

    /// @inheritdoc ISmartMToken
    function stopEarningFor(address[] calldata accounts_) external {
        for (uint256 index_; index_ < accounts_.length; ++index_) {
            stopEarningFor(accounts_[index_]);
            _revertIfHasAssociatedNullifier(accounts_[index_]);
            _stopEarningIfNotApproved(accounts_[index_]);
        }
    }

    /// @inheritdoc ISmartMToken
    function setClaimRecipient(address claimRecipient_) external {
        _accounts[msg.sender].hasClaimRecipient = (_claimRecipients[msg.sender] = claimRecipient_) != address(0);

        emit ClaimRecipientSet(msg.sender, claimRecipient_);
    }

    /* ============ Temporary Admin Migration ============ */

    /// @inheritdoc ISmartMToken
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc ISmartMToken
    function accruedYieldOf(address account_) public view returns (uint240 yield_) {
        Account storage accountInfo_ = _accounts[account_];

        return
            accountInfo_.isEarning
                ? _getAccruedYield(accountInfo_.balance, accountInfo_.earningPrincipal, currentIndex())
                : 0;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account_) public view returns (uint256 balance_) {
        return _accounts[account_].balance;
    }

    /// @inheritdoc ISmartMToken
    function balanceWithYieldOf(address account_) external view returns (uint256 balance_) {
        return balanceOf(account_) + accruedYieldOf(account_);
    }

    /// @inheritdoc ISmartMToken
    function earningPrincipalOf(address account_) public view returns (uint112 earningPrincipal_) {
        return _accounts[account_].earningPrincipal;
    }

    /// @inheritdoc ISmartMToken
    function claimRecipientFor(address account_) public view returns (address recipient_) {
        Account storage accountInfo_ = _accounts[account_];

        return
            (accountInfo_.hasNullifier)
                ? address(0)
                : (accountInfo_.hasClaimRecipient)
                    ? _claimRecipients[account_]
                    : address(
                        uint160(
                            uint256(
                                _getFromRegistrar(keccak256(abi.encode(CLAIM_OVERRIDE_RECIPIENT_KEY_PREFIX, account_)))
                            )
                        )
                    );
    }

    /// @inheritdoc ISmartMToken
    function currentIndex() public view returns (uint128 index_) {
        uint128 disableIndex_ = disableIndex == 0 ? IndexingMath.EXP_SCALED_ONE : disableIndex;

        return enableMIndex == 0 ? disableIndex_ : (disableIndex_ * _currentMIndex()) / enableMIndex;
    }

    /// @inheritdoc ISmartMToken
    function getNullifier(uint256 nullifierHash_) external view returns (address account_, uint96 nonce_) {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        return (nullifier_.account, nullifier_.nonce);
    }

    /// @inheritdoc ISmartMToken
    function isEarning(address account_) external view returns (bool isEarning_) {
        return _accounts[account_].isEarning;
    }

    /// @inheritdoc ISmartMToken
    function isEarningEnabled() public view returns (bool isEnabled_) {
        return enableMIndex != 0;
    }

    /// @inheritdoc ISmartMToken
    function excess() public view returns (uint240 excess_) {
        unchecked {
            uint128 currentIndex_ = currentIndex();
            uint240 balance_ = uint240(_getMBalanceOf(address(this)));
            uint240 earmarked_ = totalNonEarningSupply + _projectedEarningSupply(currentIndex_);

            return balance_ > earmarked_ ? _getSafeTransferableM(balance_ - earmarked_, currentIndex_) : 0;
        }
    }

    /// @inheritdoc ISmartMToken
    function totalAccruedYield() external view returns (uint240 yield_) {
        unchecked {
            uint240 projectedEarningSupply_ = _projectedEarningSupply(currentIndex());
            uint240 earningSupply_ = totalEarningSupply;

            return projectedEarningSupply_ <= earningSupply_ ? 0 : projectedEarningSupply_ - earningSupply_;
        }
    }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256 totalSupply_) {
        unchecked {
            return totalEarningSupply + totalNonEarningSupply;
        }
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

        _accounts[recipient_].isEarning
            ? _addEarningAmount(recipient_, amount_, currentIndex())
            : _addNonEarningAmount(recipient_, amount_);

        emit Transfer(address(0), recipient_, amount_);
    }

    /**
     * @dev   Burns `amount_` tokens from `account_`.
     * @param account_ The address whose account balance will be decremented.
     * @param amount_  The present amount of tokens to burn.
     */
    function _burn(address account_, uint240 amount_) internal {
        _revertIfInsufficientAmount(amount_);

        _accounts[account_].isEarning
            ? _subtractEarningAmount(account_, amount_, currentIndex())
            : _subtractNonEarningAmount(account_, amount_);

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
        Account storage accountInfo_ = _accounts[account_];

        uint240 balance_ = accountInfo_.balance;

        if (balance_ < amount_) revert InsufficientBalance(account_, balance_, amount_);

        unchecked {
            accountInfo_.balance = balance_ - amount_;
            totalNonEarningSupply -= amount_;
        }
    }

    /**
     * @dev   Increments the token balance of `account_` by `amount_`, assuming earning status.
     * @param account_      The address whose account balance will be incremented.
     * @param amount_       The present amount of tokens to increment by.
     * @param currentIndex_ The current index to use to compute the principal amount.
     */
    function _addEarningAmount(address account_, uint240 amount_, uint128 currentIndex_) internal {
        Account storage accountInfo_ = _accounts[account_];
        uint112 principal_ = IndexingMath.getPrincipalAmountRoundedDown(amount_, currentIndex_);

        // NOTE: Can be `unchecked` because the max amount of wrappable M is never greater than `type(uint240).max`.
        unchecked {
            accountInfo_.balance += amount_;
            accountInfo_.earningPrincipal = UIntMath.safe112(uint256(accountInfo_.earningPrincipal) + principal_);
        }

        _addTotalEarningSupply(amount_, principal_);
    }

    /**
     * @dev   Decrements the token balance of `account_` by `amount_`, assuming earning status.
     * @param account_      The address whose account balance will be decremented.
     * @param amount_       The present amount of tokens to decrement by.
     * @param currentIndex_ The current index to use to compute the principal amount.
     */
    function _subtractEarningAmount(address account_, uint240 amount_, uint128 currentIndex_) internal {
        Account storage accountInfo_ = _accounts[account_];
        uint240 balance_ = accountInfo_.balance;
        uint112 earningPrincipal_ = accountInfo_.earningPrincipal;

        uint112 principal_ = UIntMath.min112(
            IndexingMath.getPrincipalAmountRoundedUp(amount_, currentIndex_),
            earningPrincipal_
        );

        if (balance_ < amount_) revert InsufficientBalance(account_, balance_, amount_);

        unchecked {
            accountInfo_.balance = balance_ - amount_;
            accountInfo_.earningPrincipal = earningPrincipal_ - principal_;
        }

        _subtractTotalEarningSupply(amount_, principal_);
    }

    /**
     * @dev    Claims accrued yield for `account_` given a `currentIndex_`.
     * @param  account_     The address to claim accrued yield for.
     * @param  destination_ The destination to send yield to.
     * @return yield_       The accrued yield that was claimed.
     */
    function _claim(address account_, address destination_) internal returns (uint240 yield_) {
        Account storage accountInfo_ = _accounts[account_];

        if (!accountInfo_.isEarning) return 0;

        uint128 currentIndex_ = currentIndex();
        uint240 startingBalance_ = accountInfo_.balance;

        yield_ = _getAccruedYield(startingBalance_, accountInfo_.earningPrincipal, currentIndex_);

        if (yield_ == 0) return 0;

        unchecked {
            // Update balance and total earning supply to account for the yield, but the principals have not changed.
            accountInfo_.balance = startingBalance_ + yield_;
            totalEarningSupply += yield_;
        }

        // Emit the appropriate `Claimed` and `Transfer` events, depending on the claim override recipient
        emit Claimed(account_, destination_, yield_);
        emit Transfer(address(0), account_, yield_);

        uint240 yieldNetOfFees_ = yield_;

        if (accountInfo_.hasEarnerDetails) {
            unchecked {
                yieldNetOfFees_ -= _handleEarnerDetails(account_, yield_, currentIndex_);
            }
        }

        if ((destination_ != account_) && (yieldNetOfFees_ != 0)) {
            // NOTE: Watch out for a long chain of earning claim override recipients.
            _transfer(account_, destination_, yieldNetOfFees_, currentIndex_);
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
        (, uint16 feeRate_, address admin_) = _getEarnerDetails(account_);

        if (admin_ == address(0)) {
            // Prevent transferring to address(0) and remove `hasEarnerDetails` property going forward.
            _accounts[account_].hasEarnerDetails = false;
            return 0;
        }

        if (feeRate_ == 0) return 0;

        // TODO: Inline `UIntMath.min16` in unchecked line once it's implemented.
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

        emit Transfer(sender_, recipient_, amount_);

        if (amount_ == 0) return;

        if (sender_ == recipient_) {
            uint240 balance_ = _accounts[sender_].balance;

            if (balance_ < amount_) revert InsufficientBalance(sender_, balance_, amount_);

            return;
        }

        // TODO: Don't touch globals if both ae earning or not earning.

        _accounts[sender_].isEarning
            ? _subtractEarningAmount(sender_, amount_, currentIndex_)
            : _subtractNonEarningAmount(sender_, amount_);

        _accounts[recipient_].isEarning
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

    function _transferM(address recipient_, uint240 amount_) internal {
        // NOTE: The behavior of `IMTokenLike.transfer` is known, so its return can be ignored.
        IMTokenLike(mToken).transfer(recipient_, amount_);
    }

    /**
     * @dev   Increments total earning supply by `amount_` tokens.
     * @param amount_    The present amount of tokens to increment total earning supply by.
     * @param principal_ The principal amount of tokens to increment total earning principal by.
     */
    function _addTotalEarningSupply(uint240 amount_, uint112 principal_) internal {
        unchecked {
            // Increment the total earning supply and principal proportionally.
            totalEarningSupply += amount_;
            totalEarningPrincipal = UIntMath.safe112(uint256(totalEarningPrincipal) + principal_);
        }
    }

    /**
     * @dev   Decrements total earning supply by `amount_` tokens.
     * @param amount_    The present amount of tokens to decrement total earning supply by.
     * @param principal_ The principal amount of tokens to decrement total earning principal by.
     */
    function _subtractTotalEarningSupply(uint240 amount_, uint112 principal_) internal {
        uint240 totalEarningSupply_ = totalEarningSupply;
        uint112 totalEarningPrincipal_ = totalEarningPrincipal;

        unchecked {
            totalEarningSupply = totalEarningSupply_ - UIntMath.min240(amount_, totalEarningSupply_);
            totalEarningPrincipal = totalEarningPrincipal_ - UIntMath.min112(principal_, totalEarningPrincipal_);
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
        uint256 startingBalance_ = _getMBalanceOf(address(this));

        // NOTE: The behavior of `IMTokenLike.transferFrom` is known, so its return can be ignored.
        IMTokenLike(mToken).transferFrom(account_, address(this), amount_);

        // NOTE: When this SmartMToken contract is earning, any amount of M sent to it is converted to a principal
        //       amount at the MToken contract, which when represented as a present amount, may be a rounding error
        //       amount less than `amount_`. In order to capture the real increase in M, the difference between the
        //       starting and ending M balance is minted as SmartM.
        _mint(recipient_, wrapped_ = UIntMath.safe240(_getMBalanceOf(address(this)) - startingBalance_));
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

        uint256 startingBalance_ = _getMBalanceOf(address(this));

        _transferM(recipient_, _getSafeTransferableM(amount_, currentIndex()));

        // NOTE: When this SmartMToken contract is earning, any amount of M sent from it is converted to a principal
        //       amount at the MToken contract, which when represented as a present amount, may be a rounding error
        //       amount more than `amount_`. In order to capture the real decrease in M, the difference between the
        //       ending and starting M balance is returned.
        return UIntMath.safe240(startingBalance_ - _getMBalanceOf(address(this)));
    }

    /**
     * @dev   Tries to start earning for `account`, if allowed by the Registrar.
     * @param account_      The account to start earning for.
     * @param currentIndex_ The current index.
     */
    function _startEarningIfApproved(address account_, uint128 currentIndex_) internal {
        (bool isEarner_, , address admin_) = _getEarnerDetails(account_);

        if (!isEarner_) revert NotApprovedEarner(account_);

        _startEarning(account_, currentIndex_);

        _accounts[account_].hasEarnerDetails = admin_ != address(0); // Has earner details if an admin exists for this account.
    }

    /**
     * @dev   Starts earning for `account`, if not already started.
     * @param account_      The account to start earning for.
     * @param currentIndex_ The current index.
     */
    function _startEarning(address account_, uint128 currentIndex_) internal {
        Account storage accountInfo_ = _accounts[account_];

        if (accountInfo_.isEarning) revert AlreadyEarning(account_);

        uint240 balance_ = accountInfo_.balance;
        uint112 earningPrincipal_ = IndexingMath.getPrincipalAmountRoundedDown(balance_, currentIndex_);

        accountInfo_.isEarning = true;
        accountInfo_.earningPrincipal = earningPrincipal_;

        _addTotalEarningSupply(balance_, earningPrincipal_);

        unchecked {
            totalNonEarningSupply -= balance_;
        }

        emit StartedEarning(account_);
    }

    /**
     * @dev   Tries to stops earning for `account`, if disallowed by the Registrar.
     * @param account_ The account to stop earning for.
     */
    function _stopEarningIfNotApproved(address account_) internal {
        (bool isEarner_, , ) = _getEarnerDetails(account_);

        if (isEarner_) revert IsApprovedEarner(account_);

        _stopEarning(account_);
    }

    /**
     * @dev   Stops earning for `account`.
     * @param account_  The account to stop earning for.
     */
    function _stopEarning(address account_) internal {
        Account storage accountInfo_ = _accounts[account_];

        if (!accountInfo_.isEarning) return;

        uint240 balance_ = accountInfo_.balance;
        uint112 earningPrincipal_ = accountInfo_.earningPrincipal;

        delete accountInfo_.isEarning;
        delete accountInfo_.earningPrincipal;
        delete accountInfo_.hasEarnerDetails;
        delete accountInfo_.hasNullifier;

        _subtractTotalEarningSupply(balance_, earningPrincipal_);

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
            _getFromRegistrar(EARNERS_LIST_IGNORED_KEY) != bytes32(0) ||
            IRegistrarLike(registrar).listContains(EARNERS_LIST_NAME, address(this));
    }

    /**
     * @dev    Compute the yield given an account's balance, earning principal, and the current index.
     * @param  balance_          The token balance of an earning account.
     * @param  earningPrincipal_ The index of ast interaction for the account.
     * @param  currentIndex_     The current index.
     * @return yield_            The yield accrued since the last interaction.
     */
    function _getAccruedYield(
        uint240 balance_,
        uint112 earningPrincipal_,
        uint128 currentIndex_
    ) internal pure returns (uint240 yield_) {
        uint240 balanceWithYield_ = IndexingMath.getPresentAmountRoundedDown(earningPrincipal_, currentIndex_);

        unchecked {
            return (balanceWithYield_ <= balance_) ? 0 : balanceWithYield_ - balance_;
        }
    }

    function _getEarnerDetails(
        address account_
    ) internal view returns (bool isEarner_, uint16 feeRate_, address admin_) {
        return IEarnerManager(earnerManager).getEarnerDetails(account_);
    }

    function _getFromRegistrar(bytes32 key_) internal view returns (bytes32 value_) {
        return IRegistrarLike(registrar).get(key_);
    }

    /**
     * @dev    Compute the adjusted amount of M that can safely be transferred out given the current index.
     * @param  amount_       Some amount to be transferred out of this contract.
     * @param  currentIndex_ The current index.
     * @return safeAmount_   The adjusted amount that can safely be transferred out.
     */
    function _getSafeTransferableM(uint240 amount_, uint128 currentIndex_) internal view returns (uint240 safeAmount_) {
        // If this contract is earning, adjust `amount_` to ensure it's M balance decrement is limited to `amount_`.
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
                    uint256(_getFromRegistrar(keccak256(abi.encode(MIGRATOR_KEY_PREFIX, address(this)))))
                )
            );
    }

    function _getMBalanceOf(address account_) internal view returns (uint256 balance_) {
        return IMTokenLike(mToken).balanceOf(account_);
    }

    /**
     * @dev    Returns the projected total earning supply if all accrued yield was claimed at this moment.
     * @param  currentIndex_ The current index.
     * @return supply_       The projected total earning supply.
     */
    function _projectedEarningSupply(uint128 currentIndex_) internal view returns (uint240 supply_) {
        return IndexingMath.getPresentAmountRoundedDown(totalEarningPrincipal, currentIndex_);
    }

    /**
     * @dev   Reverts if `amount_` is equal to 0.
     * @param amount_ Amount of token.
     */
    function _revertIfInsufficientAmount(uint256 amount_) internal pure {
        if (amount_ == 0) revert InsufficientAmount(amount_);
    }

    function _revertIfInvalidExternalNullifierHash(uint256 externalNullifierHash_) internal pure {
        if (externalNullifierHash_ != EXTERNAL_NULLIFIER_HASH) revert InvalidExternalNullifierHash();
    }

    function _revertIfHasAssociatedNullifier(address account_) internal view {
        if (_accounts[account_].hasNullifier) revert HasAssociatedNullifier();
    }

    function _revertIfNullifierAccountMismatch(address nullifierAccount_, address account_) internal pure {
        if (nullifierAccount_ != account_) revert NullifierMismatch();
    }

    /**
     * @dev   Reverts if `account_` is address(0).
     * @param account_ Address of an account.
     */
    function _revertIfZeroAccount(address account_) internal pure {
        if (account_ == address(0)) revert ZeroAccount();
    }

    function _verifySemaphoreProof(
        uint256 root_,
        uint256 groupId_,
        uint256 signalHash_,
        uint256 nullifierHash_,
        uint256 externalNullifierHash_,
        uint256[8] calldata proof_
    ) internal view {
        IWorldIDRouterLike(worldIDRouter).verifyProof(
            root_,
            groupId_,
            signalHash_,
            nullifierHash_,
            externalNullifierHash_,
            proof_
        );
    }
}
