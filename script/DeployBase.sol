// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Proxy } from "../lib/common/src/Proxy.sol";

import { MToken } from "../src/MToken.sol";
import { WorldDollar } from "../src/WorldDollar.sol";

contract DeployBase {
    function deploy(
        string memory appId_,
        string memory actionId_,
        address worldIDRouter_,
        uint32 earnerRate_
    ) public virtual returns (address mToken_, address worldDollarImplementation_, address worldDollarProxy_) {
        mToken_ = address(new MToken());
        worldDollarImplementation_ = address(new WorldDollar(appId_, actionId_, mToken_, worldIDRouter_));
        worldDollarProxy_ = address(new Proxy(worldDollarImplementation_));

        MToken(mToken_).setEarnerRate(earnerRate_);
        MToken(mToken_).startEarning(worldDollarProxy_);
    }
}
