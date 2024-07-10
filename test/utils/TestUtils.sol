// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";
import { ContinuousIndexingMath } from "../../lib/common/src/libs/ContinuousIndexingMath.sol";
import { IMTokenLike } from "../../src/interfaces/IMTokenLike.sol";

import { IndexingMath } from "../../src/libs/IndexingMath.sol";
import { IRegistrarLike } from "../../src/interfaces/IRegistrarLike.sol";
import { WrappedMToken } from "../../src/WrappedMToken.sol";

import { WrappedMTokenHarness } from "./WrappedMTokenHarness.sol";

contract TestUtils is Test {
    uint56 internal constant _EXP_SCALED_ONE = 1e12;
    uint32 internal constant _EARNER_RATE = 5_000; // 5% APY

    /// @notice The earners list name in TTG.
    bytes32 internal constant _EARNERS_LIST = "earners";

    /// @notice The earners list name in TTG.
    bytes32 internal constant _EARNERS_LIST_IGNORED = "earners_list_ignored";

    /// @notice The name of parameter in TTG that defines the earner rate model contract.
    bytes32 internal constant _EARNER_RATE_MODEL = "earner_rate_model";

    /* ============ accrued yield ============ */
    function _getAccruedYield(
        uint240 startingPresentAmount_,
        uint128 startingIndex_,
        uint128 currentIndex_
    ) internal pure returns (uint240) {
        uint112 startingPrincipal_ = _getPrincipalAmountRoundedDown(startingPresentAmount_, startingIndex_);
        return _getPresentAmountRoundedDown(startingPrincipal_, currentIndex_) - startingPresentAmount_;
    }

    /* ============ earning ============ */
    function _mockIsEarning(address registrar_, address earner_, bool isEarning_) internal {
        vm.mockCall(
            registrar_,
            abi.encodeWithSelector(IRegistrarLike.get.selector, _EARNERS_LIST_IGNORED),
            abi.encode(false)
        );

        vm.mockCall(
            registrar_,
            abi.encodeWithSelector(IRegistrarLike.listContains.selector, _EARNERS_LIST, earner_),
            abi.encode(isEarning_)
        );
    }

    function _mockStartEarningMCall(WrappedMToken wrappedMToken_, address registrar_) internal {
        _mockIsEarning(registrar_, address(wrappedMToken_), true);
        wrappedMToken_.startEarningM();
    }
    /* ============ index ============ */
    function _getContinuousIndexAt(
        uint32 minterRate_,
        uint128 initialIndex_,
        uint32 elapsedTime_
    ) internal pure returns (uint128) {
        return
            uint128(
                ContinuousIndexingMath.multiplyIndicesUp(
                    initialIndex_,
                    ContinuousIndexingMath.getContinuousIndex(
                        ContinuousIndexingMath.convertFromBasisPoints(minterRate_),
                        elapsedTime_
                    )
                )
            );
    }

    function _mockUpdateIndexCall(
        IMTokenLike mToken_,
        address registrar_,
        address earnerRateModel_,
        uint32 earnerRate_
    ) internal returns (uint128) {
        vm.mockCall(
            registrar_,
            abi.encodeWithSelector(IRegistrarLike.get.selector, earnerRateModel_),
            abi.encode(earnerRateModel_)
        );

        // rate() selector 4bytes sig is 0x2c4e722e
        vm.mockCall(earnerRateModel_, abi.encodeWithSelector(0x2c4e722e), abi.encode(earnerRate_));

        return mToken_.updateIndex();
    }

    /* ============ principal ============ */
    function _getPrincipalAmountRoundedDown(uint240 presentAmount_, uint128 index_) internal pure returns (uint112) {
        return IndexingMath.divide240By128Down(presentAmount_, index_);
    }

    /* ============ present ============ */
    function _getPresentAmountRoundedDown(uint112 principalAmount_, uint128 index_) internal pure returns (uint240) {
        return IndexingMath.multiply112By128Down(principalAmount_, index_);
    }
}