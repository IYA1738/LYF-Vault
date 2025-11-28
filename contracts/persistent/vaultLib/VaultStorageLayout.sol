//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

abstract contract VaultStorageLayout{
    bytes32 internal immutable STORAGE_LAYOUT_SLOT = bytes32(uint256(keccak256("iya.vault.storage.layout")) - 1);
    struct StorageLayout{
        address admin; //控制角色管理权限，升级权限
        address accessor; //控制策略，开仓，平仓
        address vaultBaseToken; //基准资产
        address feeHandler; //收取手续费的合约

        address[] activeExternalPositions;
        address[] trackedAssets;
        mapping(address => bool) assetsToIsTracked;
        mapping(address => bool) accountToIsAssetManager;
        mapping(address => bool) externalPositionToIsActive;
    }

    function layout() internal view returns(StorageLayout storage $){
        bytes32 SLOT = STORAGE_LAYOUT_SLOT;
        assembly{
            $.slot := SLOT
        }
    }

}