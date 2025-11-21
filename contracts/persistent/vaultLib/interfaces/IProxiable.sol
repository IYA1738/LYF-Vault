//SPDX-License-Identifier:MIT
pragma solidity  >= 0.8.0 < 0.9.0;

interface IProxiable{
    function getUUID() external view returns(bytes32);
}