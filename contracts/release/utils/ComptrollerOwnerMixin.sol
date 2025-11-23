//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/utils/IComptrollerOwnerMixin.sol";
import "contracts/release/Core/Comptroller/IComptroller.sol";

abstract contract ComptrollerOwnerMixin is IComptrollerOwnerMixin{

    address public immutable COMPTROLLER;

    constructor(address _comptroller){
        COMPTROLLER = _comptroller;
    }

    function getComptrollerOwner() public view returns(address owner_){
        return IComptroller(COMPTROLLER).getOwner();
    }
    
}