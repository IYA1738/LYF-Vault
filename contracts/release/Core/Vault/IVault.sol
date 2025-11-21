//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

interface IVault{
    function initialize(
        address admin,
        address accessor,
        string memory shareName,
        string memory shareSymbol,
        bytes calldata extraInitData) external;

    function deposit() external payable;

    function withdraw(uint256 amount) external;
    
    function getAssetsBalance() external view returns(address[] memory);

    function getAllRunningStrategies(address _vaultProxy) external view returns(address[] memory);
}