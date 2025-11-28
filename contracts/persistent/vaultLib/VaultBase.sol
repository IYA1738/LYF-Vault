//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/persistent/vaultLib/utils/OnlyDelegate.sol";
import "contracts/persistent/vaultLib/utils/Proxiable.sol";
import "contracts/persistent/vaultLib/utils/Ownable2Step.sol";
import "contracts/persistent/vaultLib/VaultStorageLayout.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

abstract contract VaultBase is VaultStorageLayout,Proxiable, OnlyDelegate, Ownable2Step, ERC20Upgradeable{

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event AccessorChanged(address indexed oldAccessor, address indexed newAccessor);
    event FeeHandlerChanged(address indexed oldFeeHandler, address indexed newFeeHandler);
    event VaultBaseTokenChanged(address indexed oldVaultBaseToken, address indexed newVaultBaseToken);

    error InvalidAddress(address invalidAddress);

    function upgradeTo(address newImpl) external onlyDelegateCall{
        _authorizedUpgradeTo(newImpl);
        _upgradeTo(newImpl);
    }

    function _authorizedUpgradeTo(address newImpl) internal view onlyOwner{
        require(newImpl != address(0) && newImpl == address(this), "New Impl address is zero");
        require(_isContract(newImpl), "New impl is not contract");
    }

    //owner是项目方， admin是当前vault管理， accessor是comptroller
    function __init_VaultBase(
    address initOwner, 
    address _admin, 
    address _accessor,
    address _feeHandler, // can be zero when init
    address _vaultBaseToken,  //can be zero when init
    string memory name, 
    string memory symbol) internal onlyInitializing{
        if(initOwner == address(0) || _admin == address(0) || _accessor == address(0)){
            revert InvalidAddress(address(0));
        }
        __init_Ownable2Step(initOwner);
        __ERC20_init(name, symbol);
        StorageLayout storage $ = layout();
        $.admin = _admin;
        $.accessor = _accessor;
        $.feeHandler = _feeHandler;
        $.vaultBaseToken = _vaultBaseToken;
    }

    function setAdmin(address _admin) external onlyOwner{
        if(_admin == address(0)){
            revert InvalidAddress(address(0));
        }
        _setAdmin(_admin);
    }

    function setAccessor(address _accessor) external onlyOwner{
        if(_accessor == address(0)){
            revert InvalidAddress(address(0));
        }
        _setAccessor(_accessor);
    }

    function setFeeHandler(address _feeHandler) external onlyOwner{
        if(_feeHandler == address(0)){
            revert InvalidAddress(address(0));
        }
        _setFeeHandler(_feeHandler);
    }

    function setVaultBaseToken(address _vaultBaseToken) external onlyOwner{
        if(_vaultBaseToken == address(0)){
            revert InvalidAddress(address(0));
        }
        _setVaultBaseToken(_vaultBaseToken);
    }

    function _setVaultBaseToken(address _vaultBaseToken) internal{
        StorageLayout storage $ = layout();
        address oldVaultBaseToken = $.vaultBaseToken;
        $.vaultBaseToken = _vaultBaseToken;
        emit VaultBaseTokenChanged(oldVaultBaseToken, _vaultBaseToken);
    }

    function _setFeeHandler(address _feeHandler) internal{
        StorageLayout storage $ = layout();
        address oldFeeHandler = $.feeHandler;
        $.feeHandler = _feeHandler;
        emit FeeHandlerChanged(oldFeeHandler, _feeHandler);
    }

    function _setAdmin(address _admin) internal{
        StorageLayout storage $ = layout();
        address oldAdmin = $.admin;
        $.admin = _admin;
        emit AdminChanged(oldAdmin, _admin);
    }

    function _setAccessor(address _accessor) internal{
        StorageLayout storage $ = layout();
        address oldAccessor = $.accessor;
        $.accessor = _accessor;
        emit AccessorChanged(oldAccessor, _accessor);
    }

    function _isContract(address addr) internal view returns(bool res){
        assembly("memory-safe"){
            res := gt(extcodesize(addr), 0)
        }
    }

    modifier onlyAccessor(){
        require(msg.sender == layout().accessor, "Only Accessor");
        _;
    }

    modifier notShare(address asset){
        require(asset != address(this), "Not Share");
        _;
    }

}