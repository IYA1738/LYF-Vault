//SPDX-License-Identifier:MIT
pragma solidity  >= 0.8.0 < 0.9.0;

import "contracts/persistent/vaultLib/interfaces/IProxiable.sol";
import "contracts/persistent/vaultLib/utils/NoDelegate.sol";

abstract contract Proxiable is IProxiable, NoDelegate {
    //ERC1967 impl slot
    bytes32 internal constant _IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bytes32 internal immutable _UUID = bytes32(uint256(keccak256("iya.vault.proxy.UUID")) - 1);

    function _upgradeTo(address _impl) internal{
        require(Proxiable(_impl).getUUID() == _UUID, "MisMatched UUID");
        assembly{
            sstore(_IMPLEMENTATION_SLOT, _impl)
        }
    }

    function getUUID() public override view noDelegateCall returns(bytes32){
        return _UUID;
    }
}