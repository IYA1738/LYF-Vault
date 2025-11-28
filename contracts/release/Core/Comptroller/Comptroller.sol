//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/Core/Comptroller/IComptroller.sol";

//要有gas-relay
contract Comptroller is IComptroller{
    uint256 private constant BPS = 10_000;
    uint256 private constant SHARE_DECIMALS = 10 ** 18;
    address private immutable DISPATCHER;
    address private immutable EXTERNAL_POSITION_MANAGER;
    address private immutable FEE_MANAGER;
    address private immutable INTERGRATION_MANAGER;
    address private immutable POLICY_MANAGER:
    address private immutable PROTOCOL_FEE_RESERVE;
    address private immutable VALUE_INTERPRETER;
    address private immutable WETH_TOKEN;

    address internal denominationAsset;
    address internal vaultProxy;
    bool internal isLib;

    bool internal autoProtocolFeeSharesBuyback;
    bool internal permissionedVaultActionAllowed; //A reverse-mutex
    bool internal reentrancyLock = 1;

    mapping(address => uint256) internal acctToLastSharesBoughtTimeStamp;
    address private gasRelayPaymaster;

    event AutoProtocolFeeSharesBuybackSet(bool nextAutoProtocolFeeSharesBuyback);
    event BuyBackMaxProtocolFeeSharesFailed(bytes reason, uint256 sharesAmount, uint256 buybackValue, uint256 gav);
    event SharesBought(address buyer, uint256 receivedInvestmentAmount, uint256 sharesIssued, uint256 sharesReceived);

    modifier allowsPermissionedVaultAction(){
        _assertPermissionedVaultActionNotAllowed();
        permissionedVaultActionAllowed = true;
        _;
        permissionedVaultActionAllowed = false;
    }

    modifier lock() {
        require(reentrancyLock == 1, "Reentrancy Lock");
        reenrancyLock = 2;
        _;
        reenrancyLock = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == __msgSender(), "Ownable: caller is not the owner");
        _;
    }

    constructor(
        address _dispatcher,
        address _protocolFeeReserve,
        address _valueInterpreter,
        address _externalPositionManager,
        address _feeManager,
        address _integrationManager,
        address _policyManager,
        address _gasRelayPaymasterFactory,
        address _wethToken
    ) public GasRelayRecipientMixin(_gasRelayPaymasterFactory) {
        DISPATCHER = _dispatcher;
        EXTERNAL_POSITION_MANAGER = _externalPositionManager;
        FEE_MANAGER = _feeManager;
        INTEGRATION_MANAGER = _integrationManager;
        POLICY_MANAGER = _policyManager;
        PROTOCOL_FEE_RESERVE = _protocolFeeReserve;
        VALUE_INTERPRETER = _valueInterpreter;
        WETH_TOKEN = _wethToken;
        isLib = true;
    }

    function callOnExtension(
        address _extension,
        uint256 actionId,
        bytes memory callArgs) external override lock allowsPermissionedVaultAction{
            require(_extension == getFeeManager() || _extension == getIntegrationManager()
                || _extension == getExternalPositionManager(), "Invalid extension");
            IExtension(_extension).receiveCallFromComptroller(__msgSender(), actionId, callArgs);
        }
    
    function vaultCallOnContract(address _contract, bytes4 _selector, bytes calldata _data)
    external
    override
    onlyOwner
    returns(bytes memory ret){
        return IVault(getVaultProxy()).callOnContract(_contract, abi.encodePacked(_selector, _data));
    }

    function buybackProtocolFeeShares(uint256 _sharesAmount) external override{
        address vaultProxyCopy = vaultProxy;
        require(IVault(vaultProxyCopy).canManageAssers(__msgSender()),"unauthorized");
        uint256 gav = calcGav();
        //IVault(vaultProxyCopy).buybackProtocolFeeShares(_sharesAmount)
    }

    function setAutoProtocolFeeSharesBuyback(bool _nextAutoProtocolFeeSharesBuyback) external override onlyOwner {
        autoProtocolFeeSharesBuyback = _nextAutoProtocolFeeSharesBuyback;

        emit AutoProtocolFeeSharesBuybackSet(_nextAutoProtocolFeeSharesBuyback);
    }

    function _buybackMaxProtocolFeeShares(address _vaultProxy, uint256 gav) private{
        uint256 sharesAmount = IERC20(_vaultProxy).balanceOf(getProtocolFeeReserve());
        uint256 buybackValue = _getBuybackValue(_vaultProxy, sharesAmount, gav);

        try IVault(_vaultProxy).buybackProtocolFeeShares(sharesAmount, buybackValue, gav);
        catch(bytes memory reason){
            emit BuyBackMaxProtocolFeeSharesFailed(reason, sharesAmount, buybackValue, gav);
        }
    }

    function _getBuybackValue(address _vaultProxy, uint256 _sharesAmount, uint256 _gav)
    private
    returns(uint256 buybackValue){
        address denominationAssetCopy = getDenominationAsset();

        uint256 grossShareValue = _calcGrossShareValue(
            _gav,
             IERC20(_vaultProxy).totalSupply(), 
             10 ** uint256(IERC20(denominationAssetCopy).decimals());
        );
        uint256 buybackValueInDenominationAsset = Math.mulDiv(
            grossShareValue,
            _sharesAmount,
            SHARE_DECIMALS,
            Math.Rounding.Floor
        );
        return IValueInterpreter(getValueInterpreter())
        .calcCanonicalAssetValue(denominationAssetCopy, buybackValueInDenominationAsset, getToken());
    }

    function permissionedVaultAction(IVault.VaultAction _action, bytes calldata _actionData)
    external override{
        _assertPermissionedVaultAction(msg.sender, _action);
        if(_action == IVault.VaultAction.RemoveTrackedAsset){
            require(abi.decode(_actionData, (address)) != getDenominationAsset(),
            "Cannot untrack denomination asset"
            );
        }
        IVault(getVaultProxy()).receiveValidatedVaultAction(_action, _actionDara));
    }

    function _assertPermissionedVaultAction(address _caller, IVault.VaultAction _action) private view {
        bool validAction;
        if (permissionedVaultActionAllowed) {
            if (_caller == getIntegrationManager()) {
                if (
                    _action == IVault.VaultAction.AddTrackedAsset || _action == IVault.VaultAction.RemoveTrackedAsset
                        || _action == IVault.VaultAction.WithdrawAssetTo
                        || _action == IVault.VaultAction.ApproveAssetSpender
                ) {
                    validAction = true;
                }
            } else if (_caller == getFeeManager()) {
                if (
                    _action == IVault.VaultAction.MintShares || _action == IVault.VaultAction.BurnShares
                        || _action == IVault.VaultAction.TransferShares
                ) {
                    validAction = true;
                }
            } else if (_caller == getExternalPositionManager()) {
                if (
                    _action == IVault.VaultAction.CallOnExternalPosition
                        || _action == IVault.VaultAction.AddExternalPosition
                        || _action == IVault.VaultAction.RemoveExternalPosition
                ) {
                    validAction = true;
                }
            }
        }

        require(validAction, "__assertPermissionedVaultAction: Action not allowed");
    }

    function init(address _denominationAsset, uint256 _sharesActionTimelock) external override onlyOwner{
        require(getDenominationAsset() == address(0), "init: Already initialized");
        require(
            IValueInterpreter(getValueInterpreter()).isSupportedPrimitiveAsset(_denominationAsset),
            "init: Bad denomination asset"
        );

        denominationAsset = _denominationAsset;
        sharesActionTimelock = _sharesActionTimelock;
    }

    function setVaultProxy(address _vaultProxy) external override onlyOwner {
        vaultProxy = _vaultProxy;

        emit VaultProxySet(_vaultProxy);
    }

    function calcGav() public override returns(uint256 gav_){
        address vaultProxyAddress = getVaultProxy();
        address[] memory assets = IVault(vaultProxyAddress).getTrackedAssets();
        address[] memory externalPositions = IVault(vaultProxyAddress).getActiveExternalPositions();

        if(assets.length == 0 && externalPositions.length == 0){
            return 0;
        }

        uint256[] memory balances = new uint256[](assets.length);
        for(uint256 i; i < assets.length;){
            balances[i] = IERC20(assets[i]).balanceOf(vaultProxyAddress);
            unchecked {
                i++;
            }
        }
        gav_ = IValueInterpreter(getValueInterpreter())
        .calcCanonicalAssetsTotalValue(assets, balances, getDenominationAsset());
        if(externalPositions.length > 0){
            for(uint i; i < externalPositions.length;){
                uint256 externalPositionValue = _calcExternalPositionValue(externalPositions[i]);
                gav_ += externalPositionValue;
                unchecked {
                    i++;
                }
            }
        }
        return gav_;
    }

    function calcGrossShareValue() external override returns(uint256 grossShareValue_){
        uint256 gav = calcGav();
        grossShareValue_ = _calcGrossShareValue(
            gav,
            IERC20(getVaultProxy()).totalSupply(),
            10 ** uint256(IERC20(getDenominationAsset()).decimals())
        )
        return grossShareValue_;
    }

    function _calcExternalPositionValue(address _externalPosition) private returns(uint256 value_){
        (address[] memory managedAssets, uint256[] memory managedAmounts) = 
        IExternalPosition(_externalPosition).getManagedAssets();

        uint256 managedValue = IVaultInterpreter(getValueInterpreter()).
        calCanonicalAssetsTotalValue = managedAssets, managedAmounts, getDenominationAsset());
        
        (address[] memory debtAssets, uint256[] memory debtAmounts) = 
        IExternalPosition(_externalPosition).getDebtAssets();

        uint256 debtValue = IVaultInterpreter(getValueInterpreter()).
        calCanonicalAssetsTotalValue = debtAssets, debtAmounts, getDenominationAsset());

        if(managedValue > debtValue){
            value_ = managedValue - debtValue;
        }
        return value_;
    }

    function _calcGrossShareValue(uint256 _gav, uint256 _totalSupply, uint256 _denominationAssetUnit)
    private
    pure
    returns(uint256 grossShareValue){
        if(_totalSupply == 0){
            return 0;
        }
        return Math.mulDiv(_gav, _denominationAssetUnit, _totalSupply, Math.Rounding.Ceil);
    }

    //Participation

    function buySharesOnBehalf(address _buyer, uint256 _investmentAmount, uint256 _minSharesQuantity)
    external
    override
    returns(uint256 sharesReceived_){
        bool hasSharesActionTimelock = getSharesActionTimelock() > 0;
        address canonicalSender = __msgSender();
        require(!hasSharesActionTimelock||
        IFundDeployer(getFundDeployer()).isAllowedBuySharesOnBehalfCaller(canonicalSender),
        "unauthorized"
        );
        return _buyShares(_buyer, _investmentAmount, _minSharesQuantity, hasSharesActionTimelock, canonicalSender);
    }

    function buyShares(uint256 _investmentAmount, uint256 _minSharesQuantity)
    external
    override
    returns(uint256 sharesReceived_){
        bool hasSharesActionTimelock = getSharesActionTimelock() > 0;
        address canonicalSender = __msgSender();
        return _buyShares(canonicalSender, _investmentAmount, _minSharesQuantity, hasSharesActionTimelock, canonicalSender);
    }

    function _buyShares(address _buyer, uint256 _investmentAmount, uint256 _minSharesQuantity, bool _hasSharesActionTimelock, address _canonicalSender) 
    private 
    lock
    allowsPermissionedVaultAction
    returns(uint256 sharesReceived_){
        address vaultProxyCopy = getVaultProxy();
        
        uint256 gav = calcGav();

        //处理mint之前的事情
        //实际investment Amount不一定等于investmentAmount
        //因为可能有fee-on-transfer
        _preBuySharesHook(_buyer, _investmentAmount, gav);

        IVault(vaultProxyCopy).payProtocolFee();

        if(doesAutoProtocolFeeSharesBuyback()){
            _buybackMaxProtocolFeeShares(vaultProxyCopy, gav);
        }

        uint256 receivedInvestmentAmount = _transferFromWithReceivedAmount(
            getDenominationAsset(),
            _canonicalSender,
            vaultProxyCopy,
            _investmentAmount
        );
        
        uint256 sharePrice = _calcGrossShareValue(
            gav,
            IERC20(vaultProxyCopy).totalSupply(),
            10 ** uint256(IERC20(getDenominationAsset()).decimals())
        );
        
        uint256 sharesIssued = Math.mulDiv(
            receivedInvestmentAmount,
            SHARE_DECIMALS,
            sharePrice,
            Math.Rounding.Floor
        );

        uint256 prevBuyerShares = IERC20(vaultProxyCopy).balanceOf(_buyer);

        IVault(vaultProxyCopy).mintShares(_buyer, sharesIssued);

        _postBuySharesHook(_buyer, receivedInvestmentAmount, sharesIssued, gav);

        sharesReceived_ = IERC20(vaultProxyCopy).balanceOf(_buyer) - prevBuyerShares;

        require(sharesReceived_ >= _minSharesQuantity, "sharesReceived < minSharesQuantity");   

        if(_hasSharesActionTimelock){
            accToLastSharesBoughtTimestamp[_buyer] = block.timestamp;
        }

        emit SharesBought(_buyer, receivedInvestmentAmount, sharesIssued, sharesReceived_);

        return sharesReceived_;
    }

    function _preBuySharesHook(address _buyer, uint256 _investmentAmount, uint256 _gav) private{
        IFeeManager(getFeemanager())
        .invokeHook(
            IFeeManager.FeeHook.PreBuyShares,
            abi.encode(
                _buyer,
                _investmentAmount
            ),
            gav
        );
    }

    function _postBuySharesHook(
        address _buyer,
        uint256 _investmentAmount,
        uint256 _sharesIssued,
        uint256 _preBuySharesGav
    ) private{
        uint256 gav = _prevBuySharesGav + _investmentAmount;
        IFeeManager(getFeeManager())
            .invokeHook(IFeeManager.FeeHook.PostBuyShares, 
            abi.encode(_buyer, _investmentAmount, _sharesIssued), gav);
        
        IPolicyManager(getPolicyManager()).validatePolicies(
            address(this),
            IPolicyManager.PolicyHook.PostBuyShares,
            abi.encode(_buyer, _investmentAmount, _sharesIssued, gav)
        )
    }

    function _transferFromWithReceivedAmount(
        address token, address from, address to, uint256 amount) 
        private returns(uint256 receivedAmount){
        uint256 prevTransferBal = IERC20(token).balanceOf(to);
        IERC20(token).safeTransferFrom(from, to, amount);
        uint256 receivedAmount = IERC20(token).balanceOf(to) - prevTransferBal;
        return receivedAmount;
    }

    //Redeem
    function redeemSharesForSpecificAssets(
        address _recipient,
        uint256 _sharesQuantity,
        address[] calldata _payoutAssets,
        address[] calldata _payoutAssetPercentages
    ) external override lock returns(uint256[] memory payoutAmounts_){
        address canonicalSender = __msgSender();
        require(payoutAssets.length == payoutAssetPercentages.length, "length mismatch");
        require(_payoutAssets.isUniqueSet(), "duplicate asset");

        uint256 gav = calcGav();

        IVault vaultProxyContract = IVault(getVaultProxy());

        (uint256 sharesToRedeem, uint256 sharesSupply) = 
        _redeemSharesSetup(vaultProxyContract, canonicalSender, _sharesQuantity, true, gav);

        payoutAmounts_ = _payoutSpecifiedAssetPercentages(
            vaultProxyContract,
            _recipient,
            _payoutAssets,
            _payoutAssetPercentages,
            Math.mulDiv(gav, sharesToRedeem, sharesSupply, Math.Rounding.Floor)
        );

        __postRedeemSharesForSpecificAssetsHook(
            canonicalSender, _recipient, sharesToRedeem, _payoutAssets, payoutAmounts_, gav
        );

        emit SharesRedeemed(canonicalSender, _recipient, sharesToRedeem, _payoutAssets, payoutAmounts_);

        return payoutAmounts_;
    }

    function _payoutSpecifiedAssetPercentages(
        IVault vaultProxyContract,
        address _recipient,
        address[] calldata _payoutAssets,
        address[] calldata _payoutAssetPercentages,
        uint256 _owedGav
    ) private returns(uint256[] memory payoutAmounts_){
        address denominationAssetCopy = getDenominationAsset();
        uint256 percentagesTotal;
        payoutAmounts_ = new uint256[_payoutAssets.length];
        uint256 payoutAssetsCount = _payoutAssets.length;
        for(uint i; i < payoutAssetsCount;){
            percentagesTotal += _payoutAssetPercentages[i];
            unchecked {
                i++;
            }
        }
    }

}