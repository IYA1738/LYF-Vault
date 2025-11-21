//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IMinimumERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() public view virtual returns (uint8)；
}