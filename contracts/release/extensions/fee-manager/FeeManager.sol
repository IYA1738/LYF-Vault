//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/utils/AddressArrayLib.sol";
import "contracts/release/Core/Comptroller/IComptroller.sol";
import "contracts/release/Core/Vault/IVault.sol";
import "contracts/release/extensions/utils/ExtensionBase.sol";
import "contracts/release/extensions/fee-manager/IFee.sol";
import "contracts/release/extensions/fee-manager/IFeeManager.sol";
import "contracts/utils/PermissionedVaultActionMixin.sol";

contract FeeManager is IFeeManager, ExtensionBase, PermissionedVaultActionMixin{
    using AddressArrayLib for address[];
    
    event FeeEnabledForFund(address indexed comptrollerProxy, address indexed fee, bytes settingsData);

    mapping(address => address[]) private comptrollerProxyToFees;
    
}