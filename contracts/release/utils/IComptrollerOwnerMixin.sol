//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IComptrollerOwnerMixin{
    function setComptroller(address _comptroller) external;

    function getOwner() external view returns(address);
}