//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/persistent/vaultLib/interfaces/IProxiable.sol";

contract VaultProxy{
    //ERC1967 impl slot
    bytes32 internal constant _IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bytes32 internal immutable _UUID = bytes32(uint256(keccak256("iya.vault.proxy.UUID")) - 1);

    constructor(address impl, bytes memory constructorData){
        require(IProxiable(impl).getUUID() == _UUID, "Mismatched UUID");

        assembly{
            sstore(_IMPLEMENTATION_SLOT, impl)
        }

        (bool ok, bytes memory ret) = impl.delegatecall(constructorData);
        require(ok, string(ret));
    }

    function implementation() public view returns(address impl_){
        assembly{
            impl_ := sload(_IMPLEMENTATION_SLOT)
        }
    }

    fallback() external payable{
        assembly{
            let impl := sload(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(sub(gas(), 10000), impl, 0x0, calldatasize(), 0, 0)
            let retSize := returndatasize()
            returndatacopy(0x0, 0x0, retSize)
            switch success
            case 0{
                revert (0, retSize)
            }
            default{
                return (0, retSize)
            }

        }
    }

    receive() external payable{}
}
