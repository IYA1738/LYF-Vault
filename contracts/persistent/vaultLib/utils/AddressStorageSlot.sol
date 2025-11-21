//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

abstract contract AddressStorageSlot{
    struct AddressSlot{
        address value;
    }

    function getAddressSlot(bytes32 SLOT) internal pure returns(AddressSlot storage $){
        bytes32 slot = SLOT;
        assembly{
            $.slot := slot
        }
        return $;
    }
}