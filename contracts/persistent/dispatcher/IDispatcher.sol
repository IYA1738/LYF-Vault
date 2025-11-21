//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 < 0.9.0;

interface IDispatcher{
    function deployeProxy(
    address impl,
    address admin,
    address accessor,
    string memory shareName,
    string memory shareSymbol,
    bytes calldata extraInit 
) external returns (address vaultProxy);

function updateVaultForProxy(address _proxy , address newImpl) external;

}