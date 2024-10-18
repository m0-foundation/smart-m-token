// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

contract MockM {
    uint128 public currentIndex;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address account => bool isEarning) public isEarning;

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
    address public vault;

    mapping(bytes32 key => bytes32 value) public get;

    mapping(bytes32 list => mapping(address account => bool contains)) public listContains;

    function set(bytes32 key_, bytes32 value_) external {
        get[key_] = value_;
    }

    function setListContains(bytes32 list_, address account_, bool contains_) external {
        listContains[list_][account_] = contains_;
    }

    function setVault(address vault_) external {
        vault = vault_;
    }
}
