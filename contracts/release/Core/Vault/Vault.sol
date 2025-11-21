//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/Core/Vault/IVault.sol";
import "contracts/persistent/vaultLib/VaultBase.sol";
import "contracts/release/infrastructure/VaultValueCalculator.sol";
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

contract Vault is IVault, VaultBase, ReentrancyGuardUpgradeable, PausableUpgradeable{
    using SafeERC20 for IERC20;

    event Deposited(address indexed caller,address token ,uint256 amount, uint256 mintShare);
    event Withdrawed(address indexed caller,address token ,uint256 amount);
    event AddSupportedToken(address token);
    event WithdrawRedeemQueue(address indexed caller,address token ,uint256 amount);
    event PullFundFromStrategy(address indexed strategy, address token, uint256 amount);
    event PushFundToStrategy(address token, uint256 amount);

    error NotSupportedToken(address token);
    error ExceededVaultCap();
    error BadParams();
    error InsufficientBalance();

    //address public comptroller;

    address public redeemQueue;
    address public vaultBaseToken;
    address public priceFeed;
    address public WETH;

    uint256 public constant OFFSET = 10 ** 18;
    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_VAULT_CAP = 1_000_000_000_000;

    uint256 public currentTotalValue; //In Vault, calculated by baseline token

    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public assetsBalance;

    function initialize(
        address admin,
        address accessor,
        address _redeemQueue,
        address _feeHandler,
        address _vaultBaseToken,
        string memory shareName,
        string memory shareSymbol,
        bytes calldata extraInitData
    ) external onlyInitializing{
        __init_VaultBase(msg.sender, admin, accessor, _feeHandler, _vaultBaseToken, shareName, shareSymbol);
        __Pausable_init();
        __ReentrancyGuard_init();
        (address _vaultBaseToken , address _priceFeed , address _WETH)= abi.decode(extraInitData, (address, address, address));
        priceFeed = _priceFeed;
        WETH = _WETH;
        redeemQueue = _redeemQueue;
    }

    constructor(){
        _disableInitializers();
    }

    modifier onlyComptroller(){
        require(layout().accessor == msg.sender, "Not Comptroller");
        _;
    }

    function deposit(address token,uint256 amount) external nonReentrant whenNotPaused{   //支持payable 还需要用wrapped ETH
        if(!supportedTokens[token]){
            revert NotSupportedToken(token);
        }
        if(amount == 0){
            revert BadParams();
        }
        if(amount + currentTotalValue > MAX_VAULT_CAP){
            revert ExceededVaultCap();
        }
        if(IERC20(token).balanceOf(msg.sender) < amount){
            revert InsufficientBalance();
        }

        _deposit(token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant whenNotPaused{
        if(!supportedTokens[token]){
            revert NotSupportedToken(token);
        }
        if(amount == 0){
            revert BadParams();
        }
        if(IERC20(address(this)).balanceOf(msg.sender) < amount){
            revert InsufficientBalance();
        }
        _withdraw(token, amount);
    }

    function depositETH() external payable nonReentrant whenNotPaused{
        require(msg.value > 0, "Insufficient ETH");
        if(!supportedTokens[WETH]){
            revert NotSupportedToken(WETH);
        }
        IWETH(WETH).deposit{value: msg.value}();
        _deposit(WETH, msg.value);
    }

    // assetAmount is baseToken, amount is the token which user deposit
    function _deposit(address token, uint256 amount) internal{

        uint256 convertRate = IChainlinkPriceFeedsRouter(priceFeed).getPrice1e18(token, layout().vaultBaseToken);
        uint256 assetAmount = Math.mulDiv(amount , convertRate, OFFSET, Math.Rounding.Floor); 
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 actualAmount = amount - IFeeHandler(layout().feeHandler).feePayingHook(IFeeHandler.ChargeType.UserDeposit, address(this), token, amount);
        uint256 shouldMint = _convertAssetToShare(actualAmount);
        if(currentTotalValue + actualAmount > MAX_VAULT_CAP){
            revert ExceededVaultCap();
        }
        currentTotalValue += Math.mulDiv(actualAmount , convertRate, OFFSET, Math.Rounding.Floor);
        assetsBalance[token] += actualAmount;

        _mint(msg.sender, shouldMint);

        emit Deposited(msg.sender, token, amount, shouldMint);
    }

    function _withdraw(address token,uint256 shareAmount) internal{
        uint256 assetAmount = _convertShareToAsset(shareAmount);
        uint256 convertRate = IChainlinkPriceFeedsRouter(priceFeed).getPrice1e18(token, layout().vaultBaseToken);
        uint256 withdrawAmount = Math.mulDiv(assetAmount, OFFSET, convertRate, Math.Rounding.Floor);
        
        if(withdrawAmount > assetsBalance[token]){
            IRedeemQueue.RedeemRequest memory redeemRequest = IRedeemQueue.RedeemRequest({
                user:msg.sender,
                sharesAmount:shareAmount,
                token:token,
                assetsValueWhenRedeemed:assetAmount
            })
            IRedeemQueue(redeemQueue).requestRedeemQueue(redeemRequest);
            emit WithdrawRedeemQueue(msg.sender, token, withdrawAmount);
            }
        }else{
            _burn(msg.sender, shareAmount);

            assetsBalance[token] -= withdrawAmount;

            currentTotalValue -= assetAmount;

            uint256 actualWithDraw = withdrawAmount - IFeeHandler(layout().feeHandler).feePayingHook(IFeeHandler.ChargeType.UserRedeem, address(this), token, withdrawAmount);

            IERC20(token).safeTransfer(msg.sender, actualWithDraw);

            emit Withdrawed(msg.sender, token, actualWithDraw);
        }
    }

    function previewWithdraw(address token, uint256 shareAmount) public view returns(uint256 fee_){
        uint256 assetAmount = _convertShareToAsset(shareAmount);
        uint256 convertRate = IChainlinkPriceFeedsRouter(priceFeed).getPrice1e18(token, layout().vaultBaseToken);
        uint256 withdrawAmount = Math.mulDiv(assetAmount, OFFSET, convertRate, Math.Rounding.Floor);
        fee_ = IFeeHandler(layout().feeHandler).previewWithdraw(IFeeHandler.ChargeType.UserRedeem, address(this), withdrawAmount);
    }

    //nav = 1e18 , totalSupply = 1e18, perShare = 1e18, amount = 1e0
    //per share = nav / totalSupply
    //ShareToAsset =  share amount * per share
    //AssetToShare = Asset amount / per share
    
    // share amount for per asset = totalSupply / NAV, asset = share * per asset rate
    function _convertShareToAsset(uint256 share) internal view returns(uint256 asset_){
        if(totalSupply() == 0){
            return share;
        }
        asset_ = Math.mulDiv(share, perShareValue(), OFFSET, Math.Rounding.Floor);
    }

    // asset amount for per share = NAV / totalSupply , share = asset * per share rate
    function _convertAssetToShare(uint256 asset) internal view returns(uint256 share_){
        if(totalSupply() == 0){
            return asset;
        }
        share_ = Math.mulDiv(asset, OFFSET, perShareValue(), Math.Rounding.Floor);
    }

    function pushFundToStrategy(address token, address amount) external nonReentrant whenNotPaused onlyComptroller{
        //Do check and other operations in comptroller first
        assetsBalance[token] -= amount;
        IERC20(token).approve(layout().accessor, 0);
        IERC20(token).approve(layout().accessor, amount);
        emit PushFundToStrategy(token, amount);
    }

    function pullFundFromStrategy(address strategy, address token, address amount) external nonReentrant whenNotPaused onlyComptroller{
        //Do check and other operations in comptroller first
        assetsBalance[token] += amount;
        IERC20(token).safeTransferFrom(strategy, address(this), amount);
        emit PullFundFromStrategy(strategy, token, amount);
    }

    //shareRate_ = 1e18
    function perShareValue() public view returns(uint256 shareRate_){
        if(totalSupply() == 0){
            return 0;
        }
        uint256 vaultNAV = getVaultNAV(address(this), layout().vaultBaseToken);
        //make sure shareRate_ is 1e18, if we don't time OFFSET
        //shareRate_ = nav * 1e18 / totalSupply * 1e18 = nav / totalSupply
        //for now, it will be that nav * 1e18 * 1e18 / totalSupply * 1e18 = nav / totalSupply * 1e18 = nav * 1e18 / totalSupply
        //so prevent precision loss and calculating a float number
        shareRate_ = Math.mulDiv(vaultNAV, OFFSET, totalSupply(), Math.Rounding.Floor);
    }

    function addSupportedToken(address token) external onlyOwner{
        require(!supportedTokens[token] && token != address(0), "Bad Token param");
        supportedTokens[token] = true;
        emit AddSupportedToken(token);
    }

    function getCurrentTotalValue() external view returns(uint256){
        return currentTotalValue;
    }

    function getVaultOwner() external view returns(address){
        return owner();
    }

    function getAssetsBalance() external view returns(address[] memory){
        return assetsBalance;
    }

    //pause
    function paused() external onlyOwner{
        _paused();
    }

    function unpaused() external onlyOwner{
        _unpaused();
    }

}