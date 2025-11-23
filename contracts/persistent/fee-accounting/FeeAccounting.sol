//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/persistent/fee-accounting/IFeeAccounting.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract FeeAccounting is IFeeAccounting, Ownable2Step{
    using Math for uint256;
    using SafeCast for uint256;

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_FEE_RATE = 300; //3%
    uint256 public constant SECONDS_IN_YEAR = 31557600; // 60*60*24*365.25

    struct VaultFeeInfo{
        address vault;
        uint48 lastTimePaidManageFee;
        uint16 depositFeeRate;
        uint16 withdrawFeeRate;
        uint16 manageFeeRate;
    }

    mapping(address => bool) public enabledStrategy;
    mapping(address => uint256) public strategyFeeRates;
    mapping(address => VaultFeeInfo) public vaultFeeInfos;  

    event SetFeeRate(address target, uint256 feeRate);
    event RegistryVaultInfo(address vault, uint48 lastTimePaidManageFee, uint16 depositFeeRate, uint16 withdrawFeeRate, uint16 manageFeeRate);

    error InvalidStrategy();
    error InvalidFeeRate();
    error ZeroAddress();
    error InvalidChargeType();

    constructor(address initOwner) Ownable(initOwner){

    }

    function calFeeHook(IFeeAccounting.ChargeType _type, address _target, uint256 _amount) external view returns(uint256){
        if(_type == IFeeAccounting.ChargeType.UserDeposit || _type == IFeeAccounting.ChargeType.UserRedeem){
            return calVaultActionFee(_type, _target, _amount);
        }
        if(_type == IFeeAccounting.ChargeType.PushToStrategy){
            return calStrategyFee(_target, _amount);
        }
        if(_type == IFeeAccounting.ChargeType.FundManageFee){
            return calVaultManageFee(_target, _amount);
        }
    }

    function calVaultActionFee(IFeeAccounting.ChargeType _type, address _vault, uint256 amount) public view returns(uint256 fee_){
        uint16 rate;
        if(_type == IFeeAccounting.ChargeType.UserDeposit){
            rate = vaultFeeInfos[_vault].depositFeeRate;
            
        }else if(_type == IFeeAccounting.ChargeType.UserRedeem){
            rate = vaultFeeInfos[_vault].withdrawFeeRate;

        }else{
            revert InvalidChargeType();
        }
        if(rate == 0){
            return 0;
        }
        return Math.mulDiv(amount, rate, BPS, Math.Rounding.Ceil);
    } 

    function calVaultManageFee(address _vault, uint256 amount) public view returns(uint256 fee_){
        uint48 lastPaid = vaultFeeInfos[_vault].lastTimePaidManageFee;
        uint16 rate = vaultFeeInfos[_vault].manageFeeRate;
        if(rate == 0){
            return 0;
        }
       uint48 timeDiff = block.timestamp.toUint48() - lastPaid;
       if(timeDiff == 0){
         return 0;
       }
       //Fee = amount * (rate / BPS) * (timeDiff / SECONDS_IN_YEAR)
       uint256 feeOneYear = Math.mulDiv(amount, rate ,BPS, Math.Rounding.Ceil);
       return Math.mulDiv(feeOneYear, timeDiff, SECONDS_IN_YEAR, Math.Rounding.Ceil);
    }

    function calStrategyFee(address _strategy, uint256 _amount) public view returns(uint256 fee_){
        if(enabledStrategy[_strategy] == false){
            revert InvalidStrategy();
        }
        if(strategyFeeRates[_strategy] == 0){
            return 0;
        }
        return Math.mulDiv(_amount, strategyFeeRates[_strategy], BPS, Math.Rounding.Ceil);
    }

    function vaultInfoRegistry(address _vault, uint48 _lastTimePaidManageFee, uint16 _depositFeeRate, uint16 _withdrawFeeRate, uint16 _manageFeeRate) external onlyOwner{
        vaultFeeInfos[_vault].lastTimePaidManageFee = block.timestamp.toUint48();
        vaultFeeInfos[_vault].depositFeeRate = _depositFeeRate;
        vaultFeeInfos[_vault].withdrawFeeRate = _withdrawFeeRate;
        vaultFeeInfos[_vault].manageFeeRate = _manageFeeRate;
        emit RegistryVaultInfo(_vault, _lastTimePaidManageFee, _depositFeeRate, _withdrawFeeRate, _manageFeeRate);
    }

    function setStrategyFeeRates(address strategy, uint256 feeRate) external onlyOwner{
        if(feeRate > MAX_FEE_RATE){
            revert InvalidFeeRate();
        }
        if(strategy == address(0)){
            revert ZeroAddress();
        }
        strategyFeeRates[strategy] = feeRate;
        emit SetFeeRate(strategy, feeRate);
    }

    function getStrategyFeeRates(address strategy) external view returns(uint256){
        return strategyFeeRates[strategy];
    }
}