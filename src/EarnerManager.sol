// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import { IEarnerManager } from "./interfaces/IEarnerManager.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";

import { Migratable } from "./Migratable.sol";

/**
 * @title  Earner Manager allows admins to define earners without governance, and take fees from yield.
 * @author M^0 Labs
 */
contract EarnerManager is IEarnerManager, Migratable {
    /* ============ Structs ============ */

    struct EarnerDetails {
        address admin;
        uint16 feeRate;
    }

    /* ============ Variables ============ */

    /// @inheritdoc IEarnerManager
    uint16 public constant MAX_FEE_RATE = 10_000;

    /// @inheritdoc IEarnerManager
    bytes32 public constant ADMINS_LIST_NAME = "em_admins";

    /// @inheritdoc IEarnerManager
    bytes32 public constant EARNERS_LIST_IGNORED_KEY = "earners_list_ignored";

    /// @inheritdoc IEarnerManager
    bytes32 public constant EARNERS_LIST_NAME = "earners";

    /// @inheritdoc IEarnerManager
    bytes32 public constant MIGRATOR_KEY_PREFIX = "em_migrator_v1";

    /// @inheritdoc IEarnerManager
    address public immutable registrar;

    /// @inheritdoc IEarnerManager
    address public immutable migrationAdmin;

    /// @dev Mapping of account to earner details.
    mapping(address account => EarnerDetails earnerDetails) internal _earnerDetails;

    /* ============ Modifiers ============ */

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @dev   Constructs the contract.
     * @param registrar_      The address of a Registrar contract.
     * @param migrationAdmin_ The address of a migration admin.
     */
    constructor(address registrar_, address migrationAdmin_) {
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
        if ((migrationAdmin = migrationAdmin_) == address(0)) revert ZeroMigrationAdmin();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IEarnerManager
    function setEarnerDetails(address account_, bool status_, uint16 feeRate_) external onlyAdmin {
        if (earnersListsIgnored()) revert EarnersListsIgnored();

        _setDetails(account_, status_, feeRate_);
    }

    /// @inheritdoc IEarnerManager
    function setEarnerDetails(
        address[] calldata accounts_,
        bool[] calldata statuses_,
        uint16[] calldata feeRates_
    ) external onlyAdmin {
        if (accounts_.length == 0) revert ArrayLengthZero();
        if (accounts_.length != statuses_.length) revert ArrayLengthMismatch();
        if (accounts_.length != feeRates_.length) revert ArrayLengthMismatch();
        if (earnersListsIgnored()) revert EarnersListsIgnored();

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            // NOTE: The `isAdmin` check in `_setDetails` will make this costly to re-set details for multiple accounts
            //       that have already been set by the same admin, due to the redundant queries to the registrar.
            //       Consider transient storage in `isAdmin` to memoize admins.
            _setDetails(accounts_[index_], statuses_[index_], feeRates_[index_]);
        }
    }

    /* ============ Temporary Admin Migration ============ */

    /// @inheritdoc IEarnerManager
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IEarnerManager
    function earnerStatusFor(address account_) external view returns (bool status_) {
        return earnersListsIgnored() || isInRegistrarEarnersList(account_) || isInAdministratedEarnersList(account_);
    }

    /// @inheritdoc IEarnerManager
    function earnerStatusesFor(address[] calldata accounts_) external view returns (bool[] memory statuses_) {
        statuses_ = new bool[](accounts_.length);

        bool earnersListsIgnored_ = earnersListsIgnored();

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            if (earnersListsIgnored_) {
                statuses_[index_] = true;
                continue;
            }

            address account_ = accounts_[index_];

            if (isInRegistrarEarnersList(account_)) {
                statuses_[index_] = true;
                continue;
            }

            statuses_[index_] = isInAdministratedEarnersList(account_);
        }
    }

    /// @inheritdoc IEarnerManager
    function earnersListsIgnored() public view returns (bool isIgnored_) {
        return IRegistrarLike(registrar).get(EARNERS_LIST_IGNORED_KEY) != bytes32(0);
    }

    /// @inheritdoc IEarnerManager
    function isInRegistrarEarnersList(address account_) public view returns (bool isInList_) {
        return IRegistrarLike(registrar).listContains(EARNERS_LIST_NAME, account_);
    }

    /// @inheritdoc IEarnerManager
    function isInAdministratedEarnersList(address account_) public view returns (bool isInList_) {
        return _isValidAdmin(_earnerDetails[account_].admin);
    }

    /// @inheritdoc IEarnerManager
    function getEarnerDetails(address account_) external view returns (bool status_, uint16 feeRate_, address admin_) {
        if (earnersListsIgnored() || isInRegistrarEarnersList(account_)) return (true, 0, address(0));

        EarnerDetails storage details_ = _earnerDetails[account_];

        // NOTE: Not using `isInAdministratedEarnersList(account_)` here to avoid redundant storage reads.
        return _isValidAdmin(details_.admin) ? (true, details_.feeRate, details_.admin) : (false, 0, address(0));
    }

    /// @inheritdoc IEarnerManager
    function getEarnerDetails(
        address[] calldata accounts_
    ) external view returns (bool[] memory statuses_, uint16[] memory feeRates_, address[] memory admins_) {
        statuses_ = new bool[](accounts_.length);
        feeRates_ = new uint16[](accounts_.length);
        admins_ = new address[](accounts_.length);

        bool earnersListsIgnored_ = earnersListsIgnored();

        for (uint256 index_; index_ < accounts_.length; ++index_) {
            if (earnersListsIgnored_) {
                statuses_[index_] = true;
                continue;
            }

            address account_ = accounts_[index_];

            if (isInRegistrarEarnersList(account_)) {
                statuses_[index_] = true;
                continue;
            }

            EarnerDetails storage details_ = _earnerDetails[account_];

            // NOTE: Not using `isInAdministratedEarnersList(account_)` here to avoid redundant storage reads.
            if (!_isValidAdmin(details_.admin)) continue;

            statuses_[index_] = true;
            feeRates_[index_] = details_.feeRate;
            admins_[index_] = details_.admin;
        }
    }

    /// @inheritdoc IEarnerManager
    function isAdmin(address account_) public view returns (bool isAdmin_) {
        // TODO: Consider transient storage for memoizing this check.
        return IRegistrarLike(registrar).listContains(ADMINS_LIST_NAME, account_);
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Sets the earner details for `account_`, assuming `msg.sender` is the calling admin.
     * @param account_ The account under which yield could generate.
     * @param status_  Whether the account is an earner, according to the admin.
     * @param feeRate_ The fee rate to be taken from the yield.
     */
    function _setDetails(address account_, bool status_, uint16 feeRate_) internal {
        if (account_ == address(0)) revert ZeroAccount();
        if (!status_ && (feeRate_ != 0)) revert InvalidDetails(); // Fee rate must be zero if status is false.
        if (feeRate_ > MAX_FEE_RATE) revert FeeRateTooHigh();
        if (isInRegistrarEarnersList(account_)) revert AlreadyInRegistrarEarnersList(account_);

        address admin_ = _earnerDetails[account_].admin;

        // Revert if the details have already been set by an admin that is not `msg.sender`, and is still an admin.
        // NOTE: No `_isValidAdmin` here to avoid unnecessary contract call and storage reads if `admin_ == msg.sender`.
        if ((admin_ != address(0)) && (admin_ != msg.sender) && isAdmin(admin_)) {
            revert EarnerDetailsAlreadySet(account_);
        }

        if (status_) {
            _earnerDetails[account_] = EarnerDetails(msg.sender, feeRate_);
        } else {
            delete _earnerDetails[account_];
        }

        emit EarnerDetailsSet(account_, status_, msg.sender, feeRate_);
    }

    /**
     * @dev Reverts if the caller is not an admin.
     */
    function _revertIfNotAdmin() internal view {
        if (!isAdmin(msg.sender)) revert NotAdmin();
    }

    /* ============ Internal View/Pure Functions ============ */

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
     * @dev Returns whether `admin_` is a valid current admin.
     * @param admin_         The admin to check.
     * @return isValidAdmin_ True if `admin_` is a valid admin (non-zero and an admin according to the Registrar).
     */
    function _isValidAdmin(address admin_) internal view returns (bool isValidAdmin_) {
        return (admin_ != address(0)) && isAdmin(admin_);
    }
}
