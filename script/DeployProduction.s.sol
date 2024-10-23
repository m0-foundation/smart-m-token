// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { DeployBase } from "./DeployBase.sol";

contract DeployProduction is Script, DeployBase {
    error DeployerMismatch(address expected, address actual);

    error DeployerNonceTooHigh();

    error UnexpectedDeployerNonce();

    error CurrentNonceMismatch(uint64 expected, uint64 actual);

    error ExpectedProxyMismatch(address expected, address actual);

    error ResultingProxyMismatch(address expected, address actual);

    // NOTE: Ensure this is the correct Registrar testnet/mainnet address.
    address internal constant _REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;

    // NOTE: Ensure this is the correct Excess Destination testnet/mainnet address.
    address internal constant _EXCESS_DESTINATION = 0xd7298f620B0F752Cf41BD818a16C756d9dCAA34f; // Vault

    // NOTE: Ensure this is the correct M Token testnet/mainnet address.
    address internal constant _M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;

    // NOTE: Ensure this is the correct Migration Admin testnet/mainnet address.
    address internal constant _MIGRATION_ADMIN = 0x431169728D75bd02f4053435b87D15c8d1FB2C72;

    // NOTE: Ensure this is the correct deployer testnet/mainnet to use.
    address internal constant _EXPECTED_DEPLOYER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    // NOTE: Ensure this is the correct nonce to use to deploy the Proxy on testnet/mainnet.
    uint256 internal constant _DEPLOYER_PROXY_NONCE = 40;

    // NOTE: Ensure this is the correct expected testnet/mainnet address for the Proxy.
    address internal constant _EXPECTED_PROXY = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        console2.log("Deployer:", deployer_);

        if (deployer_ != _EXPECTED_DEPLOYER) revert DeployerMismatch(_EXPECTED_DEPLOYER, deployer_);

        uint64 currentNonce_ = vm.getNonce(deployer_);

        if (currentNonce_ >= _DEPLOYER_PROXY_NONCE - 1) revert DeployerNonceTooHigh();

        address expectedProxy_ = getExpectedWrappedMTokenProxy(deployer_, _DEPLOYER_PROXY_NONCE);

        if (expectedProxy_ != _EXPECTED_PROXY) revert ExpectedProxyMismatch(_EXPECTED_PROXY, expectedProxy_);

        vm.startBroadcast(deployer_);

        // Burn nonces until to 1 before `_DEPLOYER_PROXY_NONCE` since implementation is deployed before proxy.
        while (currentNonce_ < _DEPLOYER_PROXY_NONCE - 1) {
            payable(deployer_).transfer(0);
            ++currentNonce_;
        }

        if (currentNonce_ != vm.getNonce(deployer_)) revert CurrentNonceMismatch(currentNonce_, vm.getNonce(deployer_));

        if (currentNonce_ != _DEPLOYER_PROXY_NONCE - 1) revert UnexpectedDeployerNonce();

        (address implementation_, address proxy_) = deploy(_M_TOKEN, _REGISTRAR, _EXCESS_DESTINATION, _MIGRATION_ADMIN);

        vm.stopBroadcast();

        console2.log("Wrapped M Implementation address:", implementation_);
        console2.log("Wrapped M Proxy address:", proxy_);

        if (proxy_ != _EXPECTED_PROXY) revert ResultingProxyMismatch(_EXPECTED_PROXY, proxy_);
    }
}
