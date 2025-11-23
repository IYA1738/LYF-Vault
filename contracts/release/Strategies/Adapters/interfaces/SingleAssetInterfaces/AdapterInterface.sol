//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface AdapterInterface{
    function entry(address asset, uint256 amount, bytes calldata data) external;

    function exit(bytes calldata data) external;

    function externalProtocol() external view returns(address);
}