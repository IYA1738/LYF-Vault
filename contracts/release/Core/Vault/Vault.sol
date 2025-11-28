//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/Core/Vault/IVault.sol";
import "contracts/persistent/vaultLib/VaultBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "contracts/release/infrastructure/price-feeds/IChainlinkPriceFeedsRouter.sol";
import "contracts/release/utils/IERC2612Helper.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "contracts/persistent/redeem-queue/IRedeemQueue.sol";
import "contracts/release/infrastructure/protocol-fee/fee-handler/IFeeHandler.sol";
import "contracts/external-interfaces/IWETH.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "contracts/utils/AddressArrayLib.sol";

contract Vault is IVault, VaultBase, ReentrancyGuardUpgradeable, PausableUpgradeable{
    using AddressArrayLib for address[];
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    event Deposited(address indexed caller,address token ,uint256 amount, uint256 mintShare);
    event Withdrawed(address indexed caller,address token ,uint256 amount);
    event WithdrawRedeemQueue(address indexed caller,address token ,uint256 amount);

    event AddTrackedAsset(address asset);
    event ActivedExternalPosition(address externalPosition);
    event RemovedTrackedAsset(address asset);
    event RemovedExternalPosition(address externalPosition);

    event ReceivedETH(address indexed sender, uint256 amount);
    event WithdrawnAssetTo(address indexed recipient, address asset, uint256 amount);

    error NotSupportedToken(address token);
    error ExceededVaultCap();
    error BadParams();
    error InsufficientBalance();
    error TrackedAssetAlreadyExists(address asset);
    error TrackedAssetDoesNotExist(address asset);

    //address public comptroller;

    address private immutable EXTERNAL_POSITION_MANAGER;

    uint256 private immutable POSITIONS_LIMIT;
    address private immutable PROTOCOL_FEE_RESERVE;
    address private immutable PROTOCOL_FEE_TRACKER;
    address private immutable WETH_TOKEN;

    

    function __init_vault(
        address initOwner, 
        address _admin, 
        address _accessor,
        address _feeHandler, 
        address _vaultBaseToken,
        address _protocolFeeReserve,
        address _protocolFeeTracker,
        address _externalPositionManager,
        address _WETH,
        string memory name, 
        string memory symbol
    ) external onlyInitializing{
        __init_VaultBase(initOwner, _admin, _accessor, _feeHandler, _vaultBaseToken, name, symbol);
        EXTERNAL_POSITION_MANAGER = _externalPositionManager;
        PROTOCOL_FEE_RESERVE = _protocolFeeReserve;
        PROTOCOL_FEE_TRACKER = _protocolFeeTracker;
        WETH_TOKEN = _WETH;
    }

    receive() external payable {
        uint256 ethAmount = payable(address(this)).balance;
        IWETH(WETH_TOKEN).deposit{value:ethAmount}();
        emit ReceivedETH(msg.sender, ethAmount);
    }

    function buyShares(address _target, uint256 _amount) external override onlyAccessor{
        _mint(_target, _amount);
    }

    function burnShares(address _target, uint256 _amount) external override onlyAccessor{
        _burn(_target, _amount);
    }

    function receiveValidatedVaultAction(VaultAction _action, bytes calldata _actionData)
        external
        override
        onlyAccessor
    {
        if (_action == VaultAction.AddExternalPosition) {
            __executeVaultActionAddExternalPosition(_actionData);
        } else if (_action == VaultAction.AddTrackedAsset) {
            __executeVaultActionAddTrackedAsset(_actionData);
        } else if (_action == VaultAction.ApproveAssetSpender) {
            __executeVaultActionApproveAssetSpender(_actionData);
        } else if (_action == VaultAction.BurnShares) {
            __executeVaultActionBurnShares(_actionData);
        } else if (_action == VaultAction.CallOnExternalPosition) {
            __executeVaultActionCallOnExternalPosition(_actionData);
        } else if (_action == VaultAction.MintShares) {
            __executeVaultActionMintShares(_actionData);
        } else if (_action == VaultAction.RemoveExternalPosition) {
            __executeVaultActionRemoveExternalPosition(_actionData);
        } else if (_action == VaultAction.RemoveTrackedAsset) {
            __executeVaultActionRemoveTrackedAsset(_actionData);
        }  else if (_action == VaultAction.WithdrawAssetTo) {
            __executeVaultActionWithdrawAssetTo(_actionData);
        }
    }

    function __executeVaultActionAddExternalPosition(bytes memory _actionData) private {
        _addExternalPosition(abi.decode(_actionData, (address)));
    }

    function __executeVaultActionAddTrackedAsset(bytes memory _actionData) private {
        _addTrackedAsset(abi.decode(_actionData, (address)));
    }

    function __executeVaultActionApproveAssetSpender(bytes memory _actionData) private {
        (address asset, address target, uint256 amount) = abi.decode(_actionData, (address, address, uint256));

        _approveAssetSpender(asset, target, amount);
    }

    function __executeVaultActionBurnShares(bytes memory _actionData) private {
        (address target, uint256 amount) = abi.decode(_actionData, (address, uint256));

        _burn(target, amount);
    }

    function __executeVaultActionCallOnExternalPosition(bytes memory _actionData) private {
        (
            address externalPosition,
            bytes memory callOnExternalPositionActionData,
            address[] memory assetsToTransfer,
            uint256[] memory amountsToTransfer,
            address[] memory assetsToReceive
        ) = abi.decode(_actionData, (address, bytes, address[], uint256[], address[]));

        __callOnExternalPosition(
            externalPosition, callOnExternalPositionActionData, assetsToTransfer, amountsToTransfer, assetsToReceive
        );
    }

    function __executeVaultActionMintShares(bytes memory _actionData) private {
        (address target, uint256 amount) = abi.decode(_actionData, (address, uint256));

        _mint(target, amount);
    }

    function __executeVaultActionRemoveExternalPosition(bytes memory _actionData) private {
        _removeExternalPosition(abi.decode(_actionData, (address)));
    }

    function __executeVaultActionRemoveTrackedAsset(bytes memory _actionData) private {
        _removeTrackedAsset(abi.decode(_actionData, (address)));
    }

    function __executeVaultActionWithdrawAssetTo(bytes memory _actionData) private {
        (address asset, address target, uint256 amount) = abi.decode(_actionData, (address, address, uint256));
        _withdrawAssetTo(asset, target, amount);
    }

    function _approveAssetSpender(address asset, address target, uint256 amount) private{
        if(IERC20(asset).allowance(address(this), target) > 0){
            IERC20(asset).approve(target, 0);
        }
        IERC20(asset).approve(target, amount);
    }

    function _callExternalPosition(
        address externalPosition,
        bytes memory actionData,
        address[] memory assetsToTransfer,
        uint256[] memory amountsToTransfer,
        address[] memory assetsToReceive
    ) private{
        require(isActiveExternalPosition(externalPosition), "Not a active external position");
        uint256 assetToTransferCount = assetsToTransfer.length;
        for(uint i; i < assetToTransferCount;){
            _withdrawAsssetTo(assetsToTransfer[i], externalPosition, amountsToTransfer[i]);
            unchecked {
                i++;
            }
        }
        IExternalPosition(externalPosition).receiveCallFromVault(actionData);
        uint256 assetsToReceiveCount = assetsToReceive.length;
        for(uint256 i; i < assetsToReceiveCount;){
            _addTrackedAsset(assetsToReceive[i]);
        }
    }

    function callOnContract(address _contract, bytes calldata _data) external override onlyAccessor returns(bytes memory){
        (bool success, bytes memory ret) = _contract.call(_data);
        require(success, string(ret));
        return ret
    }

    function addTrackedAsset(address asset) external override onlyAccessor notShare(asset){
        if(isTrackedAsset(asset)){
            revert TrackedAssetAlreadyExists(asset);
        }
        _validatePositionLimit();
        _addTrackedAsset(asset);
    }

    function removeTrackedAsset(address asset) external override onlyAccessor{
        if(!isTrackedAsset(asset)){
            revert TrackedAssetDoesNotExist(asset);
        }
        _removeTrackedAsset(asset);
    }

    function withdrawAssetTo(address asset, address to, uint256 amount) external override onlyAccessor{
        _withdrawAsssetTo(asset, to, amount);
    }

    function _withdrawAsssetTo(address asset, address to, uint256 amount) private{
        IERC20(asset).safeTransfer(to, amount);
        emit WithdrawnAssetTo(to, asset, amount);
    }

    function _removeTrackedAsset(address asset) private{
        layout().assetsToIsTracked[asset] = false;
        layout().trackedAssets.removeStorageItem(asset);
        emit RemovedTrackedAsset(asset);
    }

    function _addTrackedAsset(address asset) private{
        
        layout().assetsToIsTracked[asset] = true;
        layout().trackedAssets.push(asset);
        emit AddTrackedAsset(asset);
    }

    function _removeExternalPosition(address externalPosition) private{
        layout().externalPositionToIsActive[externalPosition] = false;
        layout().activeExternalPositions.removeStorageItem(externalPosition);
        emit RemovedExternalPosition(externalPosition);
    }

    function _activeExternalPosition(address externalPosition) private{
        layout().externalPositionToIsActive[externalPosition] = true;
        layout().activeExternalPositions.push(externalPosition);
        emit ActivedExternalPosition(externalPosition);
    }

    function getActiveExternalPositions() public view override returns(address[] memory){
        return layout().activeExternalPositions;
    }

    function getTrackedAssets() public view override returns(address[] memory){
        return layout().trackedAssets;
    }

    function isTrackedAsset(address asset) public view override returns(bool){
        return layout().assetsToIsTracked[asset];
    }

    function isActiveExternalPosition(address externalPosition) public view override returns(bool){
        return layout().externalPositionToIsActive[externalPosition];
    }

    function getWethToken() public view returns(address){
        return WETH_TOKEN;
    }

    function getProtocolFeeReserve() public view returns(address){
        return PROTOCOL_FEE_RESERVE;
    }

    function getProtocolFeeTracker() public view returns(address){
        return PROTOCOL_FEE_TRACKER;
    }

    function getExternalPositionManager() public view returns(address){
        return EXTERNAL_POSITION_MANAGER;
    }

    function getPositionsLimit() public view returns(uint256){
        return POSITIONS_LIMIT;
    }

    function getOwner() public view override returns(address){
        return owner();
    }

    function _validatePositionLimit() private{
        require(getTrackedAssets().length + getActiveExternalPositions().length < POSITIONS_LIMIT, "ExceededVaultCap");
    }
}