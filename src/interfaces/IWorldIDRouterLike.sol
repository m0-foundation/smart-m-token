// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/**
 * @title  Subset of World Id Router v1 interface required for source contracts.
 * @author M^0 Labs
 */
interface IWorldIDRouterLike {
    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external view;
}
