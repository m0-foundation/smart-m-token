// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../lib/forge-std/src/Script.sol";

import { DeployBase } from "./DeployBase.sol";

contract DeployTestnet is Script, DeployBase {
    address internal constant _EXPECTED_DEPLOYER = 0x5CbB32455958A1AD589Bde61C72963D936b3Bcc3;

    address internal constant _WORLD_ID_ROUTER = 0x57f928158C3EE7CDad1e4D8642503c4D0201f611;

    string internal constant _APP_ID = "app_631f4131a3d7a8e447ba9ce807d32e02";

    string internal constant _ACTION = "earning";

    uint32 internal constant _EARNER_RATE = 500;

    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        console2.log("Deployer:", deployer_);

        vm.startBroadcast(deployer_);

        (address mToken_, address worldDollarImplementation_, address worldDollarProxy_) = deploy(
            _APP_ID,
            _ACTION,
            _WORLD_ID_ROUTER,
            _EARNER_RATE
        );

        vm.stopBroadcast();

        console2.log("Mock M Token address:", mToken_);
        console2.log("World Dollar Implementation address:", worldDollarImplementation_);
        console2.log("World Dollar Proxy address:", worldDollarProxy_);
    }
}
