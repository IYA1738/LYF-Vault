//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IComptroller{
    function getAllRunningStrategies(address _vaultProxy) external view returns(address[] memory);
}
