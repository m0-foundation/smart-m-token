// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IEarnerManager } from "../../src/interfaces/IEarnerManager.sol";

import { MockRegistrar } from "./../utils/Mocks.sol";
import { EarnerManagerHarness } from "../utils/EarnerManagerHarness.sol";

contract EarnerStatusManagerTests is Test {
    bytes32 internal constant _EARNERS_LIST_IGNORED_KEY = "earners_list_ignored";
    bytes32 internal constant _EARNERS_LIST_NAME = "earners";
    bytes32 internal constant _ADMINS_LIST_NAME = "em_admins";

    address internal _admin1 = makeAddr("admin1");
    address internal _admin2 = makeAddr("admin2");

    address internal _alice = makeAddr("alice");
    address internal _bob = makeAddr("bob");
    address internal _carol = makeAddr("carol");
    address internal _dave = makeAddr("dave");
    address internal _frank = makeAddr("frank");

    address internal _migrationAdmin = makeAddr("migrationAdmin");

    MockRegistrar internal _registrar;
    EarnerManagerHarness internal _earnerManager;

    function setUp() external {
        _registrar = new MockRegistrar();
        _earnerManager = new EarnerManagerHarness(address(_registrar), _migrationAdmin);

        _registrar.setListContains(_ADMINS_LIST_NAME, _admin1, true);
        _registrar.setListContains(_ADMINS_LIST_NAME, _admin2, true);
    }

    /* ============ initial state ============ */
    function test_initialState() external view {
        assertEq(_earnerManager.registrar(), address(_registrar));
    }

    /* ============ constructor ============ */
    function test_constructor_zeroRegistrar() external {
        vm.expectRevert(IEarnerManager.ZeroRegistrar.selector);
        new EarnerManagerHarness(address(0), address(0));
    }

    function test_constructor_zeroMigrationAdmin() external {
        vm.expectRevert(IEarnerManager.ZeroMigrationAdmin.selector);
        new EarnerManagerHarness(address(_registrar), address(0));
    }

    /* ============ _setDetails ============ */
    function test_setDetails_zeroAccount() external {
        vm.expectRevert(IEarnerManager.ZeroAccount.selector);

        _earnerManager.setDetails(address(0), false, 0);
    }

    function test_setDetails_invalidDetails() external {
        vm.expectRevert(IEarnerManager.InvalidDetails.selector);

        _earnerManager.setDetails(_alice, false, 1);
    }

    function test_setDetails_feeRateTooHigh() external {
        vm.expectRevert(IEarnerManager.FeeRateTooHigh.selector);

        _earnerManager.setDetails(_alice, true, 10_001);
    }

    function test_setDetails_alreadyInRegistrarEarnersList() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        vm.expectRevert(abi.encodeWithSelector(IEarnerManager.AlreadyInRegistrarEarnersList.selector, _alice));

        _earnerManager.setDetails(_alice, true, 0);
    }

    function test_setDetails_earnerDetailsAlreadySet() external {
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 1);

        vm.expectRevert(abi.encodeWithSelector(IEarnerManager.EarnerDetailsAlreadySet.selector, _alice));

        vm.prank(_admin2);
        _earnerManager.setDetails(_alice, true, 2);
    }

    function test_setDetails() external {
        vm.prank(_admin1);
        _earnerManager.setDetails(_alice, true, 1);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 1);
        assertEq(admin_, _admin1);
    }

    function test_setDetails_changeFeeRate() external {
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 1);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 1);
        assertEq(admin_, _admin1);

        vm.prank(_admin1);
        _earnerManager.setDetails(_alice, true, 2);

        (status_, feeRate_, admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 2);
        assertEq(admin_, _admin1);
    }

    function test_setDetails_remove() external {
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 1);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 1);
        assertEq(admin_, _admin1);

        vm.prank(_admin1);
        _earnerManager.setDetails(_alice, false, 0);

        (status_, feeRate_, admin_) = _earnerManager.getEarnerDetails(_alice);

        assertFalse(status_);
        assertEq(feeRate_, 0);
        assertEq(admin_, address(0));
    }

    /* ============ setEarnerDetails ============ */
    function test_setEarnerDetails_notAdmin() external {
        vm.expectRevert(IEarnerManager.NotAdmin.selector);

        vm.prank(_bob);
        _earnerManager.setEarnerDetails(_alice, true, 0);
    }

    function test_setEarnerDetails_earnersListIgnored() external {
        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));

        vm.expectRevert(IEarnerManager.EarnersListsIgnored.selector);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(_alice, true, 0);
    }

    function test_setEarnerDetails() external {
        vm.expectEmit();
        emit IEarnerManager.EarnerDetailsSet(_alice, true, _admin1, 10_000);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(_alice, true, 10_000);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 10_000);
        assertEq(admin_, _admin1);
    }

    /* ============ setEarnerDetails batch ============ */
    function test_setEarnerDetails_batch_notAdmin() external {
        vm.expectRevert(IEarnerManager.NotAdmin.selector);

        vm.prank(_alice);
        _earnerManager.setEarnerDetails(new address[](0), new bool[](0), new uint16[](0));
    }

    function test_setEarnerDetails_batch_arrayLengthZero() external {
        vm.expectRevert(IEarnerManager.ArrayLengthZero.selector);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(new address[](0), new bool[](2), new uint16[](2));
    }

    function test_setEarnerDetails_batch_arrayLengthMismatch() external {
        vm.expectRevert(IEarnerManager.ArrayLengthMismatch.selector);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(new address[](1), new bool[](2), new uint16[](2));

        vm.expectRevert(IEarnerManager.ArrayLengthMismatch.selector);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(new address[](2), new bool[](1), new uint16[](2));

        vm.expectRevert(IEarnerManager.ArrayLengthMismatch.selector);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(new address[](2), new bool[](2), new uint16[](1));
    }

    function test_setEarnerDetails_batch_earnersListIgnored() external {
        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));

        vm.expectRevert(IEarnerManager.EarnersListsIgnored.selector);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(new address[](2), new bool[](2), new uint16[](2));
    }

    function test_setEarnerDetails_batch() external {
        address[] memory accounts_ = new address[](2);
        accounts_[0] = _alice;
        accounts_[1] = _bob;

        bool[] memory statuses_ = new bool[](2);
        statuses_[0] = true;
        statuses_[1] = true;

        uint16[] memory feeRates = new uint16[](2);
        feeRates[0] = 1;
        feeRates[1] = 10_000;

        vm.expectEmit();
        emit IEarnerManager.EarnerDetailsSet(_alice, true, _admin1, 1);

        vm.expectEmit();
        emit IEarnerManager.EarnerDetailsSet(_bob, true, _admin1, 10_000);

        vm.prank(_admin1);
        _earnerManager.setEarnerDetails(accounts_, statuses_, feeRates);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 1);
        assertEq(admin_, _admin1);

        (status_, feeRate_, admin_) = _earnerManager.getEarnerDetails(_bob);

        assertTrue(status_);
        assertEq(feeRate_, 10_000);
        assertEq(admin_, _admin1);
    }

    /* ============ earnerStatusFor ============ */
    function test_earnerStatusFor_earnersListIgnored() external {
        assertFalse(_earnerManager.earnerStatusFor(_alice));

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));

        assertTrue(_earnerManager.earnerStatusFor(_alice));
    }

    function test_earnerStatusFor_inEarnersList() external {
        assertFalse(_earnerManager.earnerStatusFor(_alice));

        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        assertTrue(_earnerManager.earnerStatusFor(_alice));
    }

    function test_earnerStatusFor_setByAdmin() external {
        assertFalse(_earnerManager.earnerStatusFor(_alice));

        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 0);

        assertTrue(_earnerManager.earnerStatusFor(_alice));
    }

    function test_earnerStatusFor_earnersListIgnoredAndInEarnersList() external {
        assertFalse(_earnerManager.earnerStatusFor(_alice));

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));
        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        assertTrue(_earnerManager.earnerStatusFor(_alice));
    }

    function test_earnerStatusFor_inEarnersListAndSetByAdmin() external {
        assertFalse(_earnerManager.earnerStatusFor(_alice));

        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 0);

        assertTrue(_earnerManager.earnerStatusFor(_alice));
    }

    function test_earnerStatusFor_earnersListIgnoredAndSetByAdmin() external {
        assertFalse(_earnerManager.earnerStatusFor(_alice));

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 0);

        assertTrue(_earnerManager.earnerStatusFor(_alice));
    }

    function test_earnerStatusFor_earnersListIgnoredAndInEarnersListAndSetByAdmin() external {
        assertFalse(_earnerManager.earnerStatusFor(_alice));

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));
        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 0);

        assertTrue(_earnerManager.earnerStatusFor(_alice));
    }

    /* ============ earnerStatusesFor ============ */
    function test_earnerStatusesFor_earnersListIgnored() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;

        bool[] memory statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertFalse(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));

        statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertTrue(statuses_[0]);
        assertTrue(statuses_[1]);
        assertTrue(statuses_[2]);
    }

    function test_earnerStatusesFor_inEarnersList() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;

        bool[] memory statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertFalse(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);

        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertTrue(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);
    }

    function test_earnerStatusesFor_setByAdmin() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;

        bool[] memory statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertFalse(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);

        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 0);
        _earnerManager.setInternalEarnerDetails(_bob, _admin2, 0);

        statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertTrue(statuses_[0]);
        assertTrue(statuses_[1]);
        assertFalse(statuses_[2]);
    }

    function test_earnerStatusesFor_earnersListIgnoredAndInEarnersList() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;

        bool[] memory statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertFalse(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));
        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertTrue(statuses_[0]);
        assertTrue(statuses_[1]);
        assertTrue(statuses_[2]);
    }

    function test_earnerStatusesFor_inEarnersListAndSetByAdmin() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;

        bool[] memory statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertFalse(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);

        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);
        _registrar.setListContains(_EARNERS_LIST_NAME, _carol, true);
        _earnerManager.setInternalEarnerDetails(_bob, _admin1, 0);
        _earnerManager.setInternalEarnerDetails(_carol, _admin2, 0);

        statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertTrue(statuses_[0]);
        assertTrue(statuses_[1]);
        assertTrue(statuses_[2]);
    }

    function test_earnerStatusesFor_earnersListIgnoredAndSetByAdmin() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;

        bool[] memory statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertFalse(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 0);
        _earnerManager.setInternalEarnerDetails(_bob, _admin2, 0);

        statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertTrue(statuses_[0]);
        assertTrue(statuses_[1]);
        assertTrue(statuses_[2]);
    }

    function test_earnerStatusesFor_earnersListIgnoredAndInEarnersListAndSetByAdmin() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;

        bool[] memory statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertFalse(statuses_[0]);
        assertFalse(statuses_[1]);
        assertFalse(statuses_[2]);

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));
        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);
        _registrar.setListContains(_EARNERS_LIST_NAME, _carol, true);
        _earnerManager.setInternalEarnerDetails(_bob, _admin1, 0);
        _earnerManager.setInternalEarnerDetails(_carol, _admin2, 0);

        statuses_ = _earnerManager.earnerStatusesFor(accounts_);

        assertTrue(statuses_[0]);
        assertTrue(statuses_[1]);
        assertTrue(statuses_[2]);
    }

    /* ============ earnersListsIgnored ============ */
    function test_earnersListsIgnored() external {
        assertFalse(_earnerManager.earnersListsIgnored());

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));

        assertTrue(_earnerManager.earnersListsIgnored());
    }

    /* ============ isInRegistrarEarnersList ============ */
    function test_isInRegistrarEarnersList() external {
        assertFalse(_earnerManager.isInRegistrarEarnersList(_alice));

        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        assertTrue(_earnerManager.isInRegistrarEarnersList(_alice));
    }

    /* ============ isInAdministratedEarnersList ============ */
    function test_isInAdministratedEarnersList() external {
        assertFalse(_earnerManager.isInAdministratedEarnersList(_alice));

        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 0);

        assertTrue(_earnerManager.isInAdministratedEarnersList(_alice));
    }

    /* ============ getEarnerDetails ============ */
    function test_getEarnerDetails_earnersListIgnored() external {
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 1);

        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 0);
        assertEq(admin_, address(0));
    }

    function test_getEarnerDetails_inEarnersList() external {
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 1);

        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 0);
        assertEq(admin_, address(0));
    }

    function test_getEarnerDetails_invalidAdmin() external {
        _earnerManager.setInternalEarnerDetails(_alice, _bob, 1);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertFalse(status_);
        assertEq(feeRate_, 0);
        assertEq(admin_, address(0));
    }

    function test_getEarnerDetails() external {
        _earnerManager.setInternalEarnerDetails(_alice, _admin1, 1);

        (bool status_, uint16 feeRate_, address admin_) = _earnerManager.getEarnerDetails(_alice);

        assertTrue(status_);
        assertEq(feeRate_, 1);
        assertEq(admin_, _admin1);
    }

    /* ============ getEarnerDetails batch ============ */
    function test_getEarnerDetails_batch_earnersListIgnored() external {
        _registrar.set(_EARNERS_LIST_IGNORED_KEY, bytes32(uint256(1)));

        address[] memory accounts_ = new address[](2);
        accounts_[0] = _alice;
        accounts_[1] = _bob;

        (bool[] memory statuses_, uint16[] memory feeRates_, address[] memory admins_) = _earnerManager
            .getEarnerDetails(accounts_);

        assertTrue(statuses_[0]);
        assertEq(feeRates_[0], 0);
        assertEq(admins_[0], address(0));

        assertTrue(statuses_[1]);
        assertEq(feeRates_[1], 0);
        assertEq(admins_[1], address(0));
    }

    function test_getEarnerDetails_batch() external {
        _registrar.setListContains(_EARNERS_LIST_NAME, _alice, true);

        _earnerManager.setInternalEarnerDetails(_bob, _admin1, 1);
        _earnerManager.setInternalEarnerDetails(_carol, _frank, 2); // Invalid admin

        address[] memory accounts_ = new address[](4);
        accounts_[0] = _alice;
        accounts_[1] = _bob;
        accounts_[2] = _carol;
        accounts_[3] = _dave;

        (bool[] memory statuses_, uint16[] memory feeRates_, address[] memory admins_) = _earnerManager
            .getEarnerDetails(accounts_);

        assertTrue(statuses_[0]);
        assertEq(feeRates_[0], 0);
        assertEq(admins_[0], address(0));

        assertTrue(statuses_[1]);
        assertEq(feeRates_[1], 1);
        assertEq(admins_[1], _admin1);

        assertFalse(statuses_[2]);
        assertEq(feeRates_[2], 0);
        assertEq(admins_[2], address(0));

        assertFalse(statuses_[3]);
        assertEq(feeRates_[3], 0);
        assertEq(admins_[3], address(0));
    }

    /* ============ isAdmin ============ */
    function test_isAdmin() external view {
        assertFalse(_earnerManager.isAdmin(_alice));
        assertTrue(_earnerManager.isAdmin(_admin1));
        assertTrue(_earnerManager.isAdmin(_admin2));
    }
}
