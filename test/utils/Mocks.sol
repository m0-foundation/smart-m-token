// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockM {
    uint128 public currentIndex;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address account => bool isEarning) public isEarning;

    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {}

    function permit(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        bytes memory signature_
    ) external {}

    function transfer(address recipient_, uint256 amount_) external returns (bool success_) {
        balanceOf[msg.sender] -= amount_;
        balanceOf[recipient_] += amount_;

        return true;
    }

    function transferFrom(address sender_, address recipient_, uint256 amount_) external returns (bool success_) {
        balanceOf[sender_] -= amount_;
        balanceOf[recipient_] += amount_;

        return true;
    }

    function setBalanceOf(address account_, uint256 balance_) external {
        balanceOf[account_] = balance_;
    }

    function setCurrentIndex(uint128 currentIndex_) external {
        currentIndex = currentIndex_;
    }

    function startEarning() external {
        isEarning[msg.sender] = true;
    }

    function stopEarning() external {
        isEarning[msg.sender] = false;
    }
}

contract MockRegistrar {
    mapping(bytes32 key => bytes32 value) public get;

    mapping(bytes32 list => mapping(address account => bool contains)) public listContains;

    function set(bytes32 key_, bytes32 value_) external {
        get[key_] = value_;
    }

    function setListContains(bytes32 list_, address account_, bool contains_) external {
        listContains[list_][account_] = contains_;
    }
}

contract MockEarnerManager {
    struct EarnerDetails {
        bool status;
        uint16 feeRate;
        address admin;
    }

    mapping(address account => EarnerDetails earnerDetails) internal _earnerDetails;

    function setEarnerDetails(address account_, bool status_, uint16 feeRate_, address admin_) external {
        _earnerDetails[account_] = EarnerDetails(status_, feeRate_, admin_);
    }

    function getEarnerDetails(address account_) external view returns (bool status_, uint16 feeRate_, address admin_) {
        EarnerDetails storage earnerDetails_ = _earnerDetails[account_];

        return (earnerDetails_.status, earnerDetails_.feeRate, earnerDetails_.admin);
    }
}
