//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/Core/Vault/IVault.sol";
import "contracts/persistent/dispatcher/IDispatcher.sol";
import "contracts/persistent/vaultLib/VaultProxy.sol";

interface IVaultBase{
    function upgradeTo(address newImpl) external;
}

contract Dispatcher is IDispatcher{

    event VaultDeployed(address proxy, address impl);
    event VaultUpdated(address proxy, address newImpl);

    address private _owner; //Timelock controller

    constructor(address owner_){
        _owner = owner_;
    }

    modifier onlyOwner(){
        require(msg.sender == _owner, "Only owner");
        _;
    }

    function deployeProxy(
        address impl,
        address admin,
        address accessor,
        string memory shareName,
        string memory shareSymbol,
        bytes calldata extraInitData
    ) external override onlyOwner returns(address proxy_){
        bytes memory initData = abi.encodeWithSelector(
            IVault.initialize.selector, 
            admin,
            accessor,
            shareName,
            shareSymbol,
            extraInitData
            );
        proxy_ = address(new VaultProxy(impl, initData));
        emit VaultDeployed(proxy_, impl);
    }

    function updateVaultForProxy(address _proxy, address newImpl) external override onlyOwner{
        IVaultBase(_proxy).upgradeTo(newImpl); //Will do check in upgrateTo()
        emit VaultUpdated(_proxy, newImpl);
    }

    function dispatcherOwner() external view returns(address){
        return _owner;
    }

    function transferOwnership(address to) external onlyOwner{
        require(to != address(0) && to != _owner, "to address is invalid");
        _owner = to;
    }

}