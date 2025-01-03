// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

interface IRegistrarLike {
    function addToList(bytes32 list, address account) external;

    function removeFromList(bytes32 list, address account) external;

    function setKey(bytes32 key, bytes32 value) external;
}

interface IMTokenLike {
    function approve(address spender, uint256 amount) external returns (bool success);

    function transfer(address recipient, uint256 amount) external returns (bool success);

    function balanceOf(address account) external view returns (uint256 balance);

    function currentIndex() external view returns (uint128 index);

    function isEarning(address account) external view returns (bool earning);

    function totalEarningSupply() external view returns (uint240 supply);

    function totalNonEarningSupply() external view returns (uint240 supply);
}
