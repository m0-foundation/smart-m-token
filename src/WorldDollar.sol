// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";
import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ERC20Extended } from "../lib/common/src/ERC20Extended.sol";
import { Migratable } from "../lib/common/src/Migratable.sol";

import { IMToken } from "./interfaces/IMToken.sol";
import { IWorldDollar } from "./interfaces/IWorldDollar.sol";
import { IWorldIDRouterLike } from "./interfaces/IWorldIDRouterLike.sol";

/**
 * @title  ERC20 Token contract for a non-rebasing World Dollar token with claimable yields.
 * @author M^0 Labs
 */
contract WorldDollar is IWorldDollar, Migratable, ERC20Extended {
    /* ============ Structs ============ */

    /**
     * @dev   Struct to represent an account's balance and yield earning details.
     * @param isEarning        Whether the account is actively earning yield.
     * @param balance          The present amount of tokens held by the account.
     * @param earningPrincipal The earning principal for the account (0 for non-earning accounts).
     */
    struct Account {
        // First Slot
        bool isEarning;
        uint240 balance;
        // Second slot
        uint112 earningPrincipal;
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

    /// @inheritdoc IWorldDollar
    bytes32 public constant START_EARNING_SIGNAL_PREFIX = "start_earning";

    /// @inheritdoc IWorldDollar
    bytes32 public constant STOP_EARNING_SIGNAL_PREFIX = "stop_earning";

    /// @inheritdoc IWorldDollar
    bytes32 public constant CLAIM_SIGNAL_PREFIX = "claim";

    /// @inheritdoc IWorldDollar
    uint256 public immutable externalNullifier;

    /// @inheritdoc IWorldDollar
    address public immutable migrationAdmin;

    /// @inheritdoc IWorldDollar
    address public immutable mToken;

    /// @inheritdoc IWorldDollar
    address public immutable worldIDRouter;

    /// @inheritdoc IWorldDollar
    uint112 public totalEarningPrincipal;

    /// @inheritdoc IWorldDollar
    uint240 public totalEarningSupply;

    /// @inheritdoc IWorldDollar
    uint240 public totalNonEarningSupply;

    /// @dev Mapping of accounts to their respective `AccountInfo` structs.
    mapping(address account => Account balance) internal _accounts;

    /// @dev Mapping of nullifier hashes to their respective `Nullifier` structs.
    mapping(uint256 nullifierHash => Nullifier nullifier) internal _nullifiers;

    /* ============ Constructor ============ */

    /**
     * @dev   Constructs the contract given an M Token address and migration admin.
     * @param mToken_        The address of an M Token.
     * @param worldIDRouter_ The address of the World ID Router.
     */
    constructor(
        string memory appId_,
        string memory actionId_,
        address mToken_,
        address worldIDRouter_
    ) ERC20Extended("World Dollar", "WorldUSD", 6) {
        externalNullifier = _hashToField(abi.encodePacked(_hashToField(abi.encodePacked(appId_)), actionId_));

        if ((mToken = mToken_) == address(0)) revert ZeroMToken();
        if ((worldIDRouter = worldIDRouter_) == address(0)) revert ZeroWorldIDRouter();

        migrationAdmin = msg.sender;
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IWorldDollar
    function wrap(address recipient_, uint256 amount_) external returns (uint240 wrapped_) {
        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWorldDollar
    function wrap(address recipient_) external returns (uint240 wrapped_) {
        return _wrap(msg.sender, recipient_, UIntMath.safe240(_getMBalanceOf(msg.sender)));
    }

    /// @inheritdoc IWorldDollar
    function wrapWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external returns (uint240 wrapped_) {
        IMToken(mToken).permit(msg.sender, address(this), amount_, deadline_, v_, r_, s_);

        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWorldDollar
    function wrapWithPermit(
        address recipient_,
        uint256 amount_,
        uint256 deadline_,
        bytes memory signature_
    ) external returns (uint240 wrapped_) {
        IMToken(mToken).permit(msg.sender, address(this), amount_, deadline_, signature_);

        return _wrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWorldDollar
    function unwrap(address recipient_, uint256 amount_) external returns (uint240 unwrapped_) {
        return _unwrap(msg.sender, recipient_, UIntMath.safe240(amount_));
    }

    /// @inheritdoc IWorldDollar
    function unwrap(address recipient_) external returns (uint240 unwrapped_) {
        return _unwrap(msg.sender, recipient_, uint240(balanceOf(msg.sender)));
    }

    /// @inheritdoc IWorldDollar
    function claim(
        address destination_,
        uint256 root_,
        uint256 groupId_,
        uint256 signalHash_,
        uint256 nullifierHash_,
        uint256[8] calldata proof_
    ) external returns (uint240 yield_) {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        if (signalHash_ != _hashToField(abi.encodePacked(CLAIM_SIGNAL_PREFIX, nullifier_.nonce++, destination_))) {
            revert UnauthorizedSignal();
        }

        address account_ = nullifier_.account;

        if (account_ == address(0)) revert NullifierNotFound();

        _verifySemaphoreProof(root_, groupId_, signalHash_, nullifierHash_, proof_);

        return _claim(account_, destination_);
    }

    /// @inheritdoc IWorldDollar
    function startEarning(
        uint256 root_,
        uint256 groupId_,
        uint256 signalHash_,
        uint256 nullifierHash_,
        uint256[8] calldata proof_
    ) external {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        if (signalHash_ != _hashToField(abi.encode(START_EARNING_SIGNAL_PREFIX, nullifier_.nonce++, msg.sender))) {
            revert UnauthorizedSignal();
        }

        if (nullifier_.account != address(0)) revert NullifierAlreadyUsed();

        nullifier_.account = msg.sender;

        _verifySemaphoreProof(root_, groupId_, signalHash_, nullifierHash_, proof_);

        Account storage accountInfo_ = _accounts[msg.sender];

        if (accountInfo_.isEarning) revert AlreadyEarning();

        uint240 balance_ = accountInfo_.balance;
        uint112 earningPrincipal_ = IndexingMath.getPrincipalAmountRoundedDown(balance_, currentIndex());

        accountInfo_.isEarning = true;
        accountInfo_.earningPrincipal = earningPrincipal_;

        _addTotalEarningSupply(balance_, earningPrincipal_);

        unchecked {
            totalNonEarningSupply -= balance_;
        }

        emit StartedEarning(msg.sender, nullifierHash_);
    }

    /// @inheritdoc IWorldDollar
    function stopEarning(
        address account_,
        uint256 root_,
        uint256 groupId_,
        uint256 signalHash_,
        uint256 nullifierHash_,
        uint256[8] calldata proof_
    ) external {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        _revertIfNullifierAccountMismatch(nullifier_.account, account_);

        if (signalHash_ != _hashToField(abi.encode(STOP_EARNING_SIGNAL_PREFIX, nullifier_.nonce++, account_))) {
            revert UnauthorizedSignal();
        }

        delete nullifier_.account;

        _verifySemaphoreProof(root_, groupId_, signalHash_, nullifierHash_, proof_);

        _stopEarning(account_);
    }

    /// @inheritdoc IWorldDollar
    function stopEarning(uint256 nullifierHash_) external {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        _revertIfNullifierAccountMismatch(nullifier_.account, msg.sender);

        delete nullifier_.account;

        _stopEarning(msg.sender);
    }

    /* ============ Temporary Admin Migration ============ */

    /// @inheritdoc IWorldDollar
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IWorldDollar
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

    /// @inheritdoc IWorldDollar
    function balanceWithYieldOf(address account_) external view returns (uint256 balance_) {
        return balanceOf(account_) + accruedYieldOf(account_);
    }

    /// @inheritdoc IWorldDollar
    function earningPrincipalOf(address account_) public view returns (uint112 earningPrincipal_) {
        return _accounts[account_].earningPrincipal;
    }

    /// @inheritdoc IWorldDollar
    function currentIndex() public view returns (uint128 index_) {
        return IMToken(mToken).currentIndex();
    }

    /// @inheritdoc IWorldDollar
    function getNullifier(uint256 nullifierHash_) external view returns (address account_, uint96 nonce_) {
        Nullifier storage nullifier_ = _nullifiers[nullifierHash_];

        return (nullifier_.account, nullifier_.nonce);
    }

    /// @inheritdoc IWorldDollar
    function isEarning(address account_) external view returns (bool isEarning_) {
        return _accounts[account_].isEarning;
    }

    /// @inheritdoc IWorldDollar
    function excess() public view returns (uint240 excess_) {
        unchecked {
            uint128 currentIndex_ = currentIndex();
            uint240 balance_ = uint240(_getMBalanceOf(address(this)));
            uint240 earmarked_ = totalNonEarningSupply + _projectedEarningSupply(currentIndex_);

            return balance_ > earmarked_ ? _getSafeTransferableM(balance_ - earmarked_, currentIndex_) : 0;
        }
    }

    /// @inheritdoc IWorldDollar
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

        if (destination_ == account_) return yield_;

        _transfer(account_, destination_, yield_, currentIndex_);
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
        // NOTE: The behavior of `IMToken.transfer` is known, so its return can be ignored.
        IMToken(mToken).transfer(recipient_, amount_);
    }

    function _stopEarning(address account_) internal {
        Account storage accountInfo_ = _accounts[account_];

        if (!accountInfo_.isEarning) revert AlreadyNotEarning();

        uint240 balance_ = accountInfo_.balance;
        uint112 earningPrincipal_ = accountInfo_.earningPrincipal;

        delete accountInfo_.isEarning;
        delete accountInfo_.earningPrincipal;

        _subtractTotalEarningSupply(balance_, earningPrincipal_);

        unchecked {
            totalNonEarningSupply += balance_;
        }

        emit StoppedEarning(account_);
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

        // NOTE: The behavior of `IMToken.transferFrom` is known, so its return can be ignored.
        IMToken(mToken).transferFrom(account_, address(this), amount_);

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

    /* ============ Internal View/Pure Functions ============ */

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

    /**
     * @dev    Compute the adjusted amount of M that can safely be transferred out given the current index.
     * @param  amount_       Some amount to be transferred out of this contract.
     * @param  currentIndex_ The current index.
     * @return safeAmount_   The adjusted amount that can safely be transferred out.
     */
    function _getSafeTransferableM(uint240 amount_, uint128 currentIndex_) internal view returns (uint240 safeAmount_) {
        // If this contract is earning, adjust `amount_` to ensure it's M balance decrement is limited to `amount_`.
        return
            IMToken(mToken).isEarning(address(this))
                ? IndexingMath.getPresentAmountRoundedDown(
                    IndexingMath.getPrincipalAmountRoundedDown(amount_, currentIndex_),
                    currentIndex_
                )
                : amount_;
    }

    /// @dev Returns the address of the contract to use as a migrator, if any.
    function _getMigrator() internal pure override returns (address migrator_) {
        return address(0);
    }

    function _getMBalanceOf(address account_) internal view returns (uint256 balance_) {
        return IMToken(mToken).balanceOf(account_);
    }

    function _hashToField(bytes memory value_) internal pure returns (uint256 hash_) {
        return uint256(keccak256(value_)) >> 8;
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
        uint256[8] calldata proof_
    ) internal view {
        IWorldIDRouterLike(worldIDRouter).verifyProof(
            root_,
            groupId_,
            signalHash_,
            nullifierHash_,
            externalNullifier,
            proof_
        );
    }
}
