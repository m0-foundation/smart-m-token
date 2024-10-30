// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { EarnerManager } from "../../src/EarnerManager.sol";

contract EarnerManagerHarness is EarnerManager {
    constructor(address registrar_, address migrationAdmin_) EarnerManager(registrar_, migrationAdmin_) {}

    function setInternalEarnerDetails(address account_, address admin_, uint16 feeRate_) external {
        _earnerDetails[account_] = EarnerDetails(admin_, feeRate_);
    }

    function setDetails(address account_, bool status_, uint16 feeRate_) external {
        _setDetails(account_, status_, feeRate_);
    }
}
