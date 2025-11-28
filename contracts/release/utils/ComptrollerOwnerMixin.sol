//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/utils/IComptrollerOwnerMixin.sol";
import "contracts/release/Core/Comptroller/IComptroller.sol";

abstract contract ComptrollerOwnerMixin is IComptrollerOwnerMixin{

    address internal constant COMPTROLLER = address(0); //padding 占位

    function getComptrollerOwner() public view returns(address owner_){
        return IComptroller(COMPTROLLER).getOwner();
    }

    modifier onlyComptrollerOwner(){
        require(msg.sender == getComptrollerOwner(), "Only Comptroller Owner");
        _;
    }
}