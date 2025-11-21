//SPDX-License-Identifier:MIT
pragma solidity >= 0.8.0 < 0.9.0;

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}