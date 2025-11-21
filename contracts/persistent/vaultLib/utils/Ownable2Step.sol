//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 < 0.9.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract Ownable2Step is Initializable{
    bytes32 internal immutable OWNER_SLOT = bytes32(uint256(keccak256("iya.vault.Ownable2Step.slot")) - 1);

    struct Owner{
        address owner;
        address pendingOwner;
        uint48 executableTime;
        uint48 delayDuration;
    }

    event OwnableInit(address initialOwner);
    event OwnershipClaimed(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferd(address indexed oldOwner, address indexed newOwner);
    event SetDelay(uint48 oldDelay, uint48 newDelay);

    error OwnableInvalidOwnerAddr(address invalidOwnerAddr);
    error OwnableUnauthorizedOwner(address unauthorizedOwner);
    error OwnableNotExecutableTime();

    modifier onlyOwner{
        if(msg.sender != owner()){
            revert OwnableUnauthorizedOwner(msg.sender);
        }
        _;
    }

    function _getOwnableStorageSlot() internal view returns(Owner storage $){
        bytes32 SLOT = OWNER_SLOT;
        assembly{
            $.slot := SLOT
        }
    }

    function __init_Ownable2Step(address initOwner) internal onlyInitializing{
        if(initOwner == address(0)){
            revert OwnableInvalidOwnerAddr(address(0));
        }
        Owner storage $ = _getOwnableStorageSlot();
        $.owner = initOwner;
        emit OwnableInit(initOwner);
    }

    function transferOwnership(address to) external onlyOwner(){
        if(to == address(0)){
            revert OwnableInvalidOwnerAddr(address(0));
        }
        if(to == owner()){
            revert OwnableInvalidOwnerAddr(address(0));
        }
        _transferOwnership(to);
    }

    function claimOwnership() external{
        Owner storage $ = _getOwnableStorageSlot();
        if(msg.sender != $.pendingOwner){
            revert OwnableUnauthorizedOwner(msg.sender);
        }
        if(uint48(block.timestamp) < $.executableTime){
            revert OwnableNotExecutableTime();
        }
        _claimOwnership();
    }

    function _transferOwnership(address to) internal {
        Owner storage $ = _getOwnableStorageSlot();
        $.pendingOwner = to;
        $.executableTime = uint48(block.timestamp) + $.delayDuration;
        emit OwnershipTransferd(msg.sender, to);
    }

    function _claimOwnership() internal {
        Owner storage $ = _getOwnableStorageSlot();
        address oldOwner = $.owner;
        $.owner = $.pendingOwner;
        delete $.pendingOwner;
        delete $.executableTime;
        emit OwnershipClaimed(oldOwner, $.owner);
    }

    function setDelay(uint48 newDelay) external onlyOwner{
        require(newDelay >= 3600, "Min delay is 1 hour");
        Owner storage $ = _getOwnableStorageSlot();
        uint48 oldDelay = $.delayDuration;
        $.delayDuration = newDelay;
        emit SetDelay(oldDelay, newDelay);
    }

    function owner() public view returns(address){
        Owner storage $ = _getOwnableStorageSlot();
        return $.owner;
    }

    function pendingOwner() public view returns(address){
        Owner storage $ = _getOwnableStorageSlot();
        return $.pendingOwner;
    }

    function executableTime() public view returns(uint48){
        Owner storage $ = _getOwnableStorageSlot();
        return $.executableTime;
    }

    function delayDuration() public view returns(uint48){
        Owner storage $ = _getOwnableStorageSlot();
        return $.delayDuration;
    }
}