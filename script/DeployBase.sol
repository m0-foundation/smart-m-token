// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { ContractHelper } from "../lib/common/src/libs/ContractHelper.sol";

import { WrappedMToken } from "../src/WrappedMToken.sol";
import { EarnerManager } from "../src/EarnerManager.sol";
import { Proxy } from "../src/Proxy.sol";

contract DeployBase {
    /**
     * @dev    Deploys Wrapped M Token.
     * @param  mToken_                      The address of the M Token contract.
     * @param  registrar_                   The address of the Registrar contract.
     * @param  excessDestination_           The address of the excess destination.
     * @param  migrationAdmin_              The address of the Migration Admin.
     * @return earnerManagerImplementation_ The address of the deployed Earner Manager implementation.
     * @return earnerManagerProxy_          The address of the deployed Earner Manager proxy.
     * @return wrappedMTokenImplementation_ The address of the deployed Wrapped M Token implementation.
     * @return wrappedMTokenProxy_          The address of the deployed Wrapped M Token proxy.
     */
    function deploy(
        address mToken_,
        address registrar_,
        address excessDestination_,
        address migrationAdmin_
    )
        public
        virtual
        returns (
            address earnerManagerImplementation_,
            address earnerManagerProxy_,
            address wrappedMTokenImplementation_,
            address wrappedMTokenProxy_
        )
    {
        // Earner Manager Proxy constructor needs only known values.
        // Earner Manager Implementation constructor needs `earnerManagerImplementation_`.
        // Wrapped M Token Implementation constructor needs `earnerManagerProxy_`.
        // Wrapped M Token Proxy constructor needs `wrappedMTokenImplementation_`.

        earnerManagerImplementation_ = address(new EarnerManager(registrar_, migrationAdmin_));

        earnerManagerProxy_ = address(new Proxy(earnerManagerImplementation_));

        wrappedMTokenImplementation_ = address(
            new WrappedMToken(mToken_, registrar_, earnerManagerProxy_, excessDestination_, migrationAdmin_)
        );

        wrappedMTokenProxy_ = address(new Proxy(wrappedMTokenImplementation_));
    }

    function _getExpectedEarnerManager(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_);
    }

    function getExpectedEarnerManager(address deployer_, uint256 deployerNonce_) public pure virtual returns (address) {
        return _getExpectedEarnerManager(deployer_, deployerNonce_);
    }

    function _getExpectedEarnerManagerProxy(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 1);
    }

    function getExpectedEarnerManagerProxy(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedEarnerManagerProxy(deployer_, deployerNonce_);
    }

    function _getExpectedWrappedMTokenImplementation(
        address deployer_,
        uint256 deployerNonce_
    ) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 2);
    }

    function getExpectedWrappedMTokenImplementation(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedWrappedMTokenImplementation(deployer_, deployerNonce_);
    }

    function _getExpectedWrappedMTokenProxy(address deployer_, uint256 deployerNonce_) internal pure returns (address) {
        return ContractHelper.getContractFrom(deployer_, deployerNonce_ + 3);
    }

    function getExpectedWrappedMTokenProxy(
        address deployer_,
        uint256 deployerNonce_
    ) public pure virtual returns (address) {
        return _getExpectedWrappedMTokenProxy(deployer_, deployerNonce_);
    }

    function getDeployerNonceAfterWrappedMTokenDeployment(
        uint256 deployerNonce_
    ) public pure virtual returns (uint256) {
        return deployerNonce_ + 4;
    }
}
