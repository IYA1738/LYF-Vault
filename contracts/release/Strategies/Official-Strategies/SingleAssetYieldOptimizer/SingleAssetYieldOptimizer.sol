//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/Strategies/Official-Strategies/SingleAssetYieldOptimizer/ISingleAssetYieldOptimizer.sol";
import "contracts/release/extensions/policy-manager/IPolicyManager.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/release/Strategies/Adapters/interfaces/SingleAssetInterfaces/AdapterInterface.sol";
import "contracts/release/Strategies/StrategyBase.sol";
import "contracts/release/extensions/external-positions-manager/IExternalPositionsManager.sol";

//此合约的作用为计算策略收益和将链下计划好的策略路径转发给具体的Adapter去执行

contract SingleAssetYieldOptimizer is ISingleAssetYieldOptimizer, StrategyBase{
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOOP_TIMES = 50;
    uint256 constant GAS_BUFFER      = 30_000; //单次执行预估gas
    uint256 constant GAS_MIN_RESERVE = 20_000; //留来做后续收尾

    address public extPositionManager;

    address[] public rewardTokens;

    //记录仓位信息

    error InvalidParams();
    error OutOfGas(uint256 faildIndex);
    error LoopTimesExceed();

    event InsufficientGasExecuteNext(address indexed strategy, uint256 failedIndex);
     
    function entry (address[] calldata adapters, address[] calldata assets, uint256[] calldata amounts,bytes[] calldata datas) external override onlyRole(STRATEGY_OPERATOR_ROLE){
        if(adapters.length != assets.length || adapters.length != amounts.length || adapters.length != datas.length){
            revert InvalidParams();
        }
        uint256 length = adapters.length;
        if(length >= MAX_LOOP_TIMES){
            revert LoopTimesExceed(); //限制过长数组，防止OOG
        }
        for(uint256 i = 0; i < length;){
            if(gasleft() < GAS_BUFFER + GAS_MIN_RESERVE){
                emit InsufficientGasExcuteNext(address(this), i); //gas不够了，emit事件然后退出，off-chain拿失败的index去重跑剩下的策略，OOG是控制内的错误，已成功的不回滚
                return;
            }
            address adapter = adapters[i];
            (bool success, bytes memory ret) = adapter.call(
                abi.encodeWithSelector(AdapterInterfaces.entry.selector,
                    assets[i],
                    amounts[i],
                    datas[i]
                )
            );
            if(!success && ret.length == 0){
                revert OutOfGas(i); //OOG及未知错误 上方OOG兜底失败或未知错误都是控制外的错误，应整体revert回滚来控制风险
            }
            if(!success && ret.length > 0){ //有return的错误，但仍然是需要人工检查的错误，应整体revert且回传returnData后回滚来控制风险
                assembly {
                revert(add(ret, 0x20), mload(ret))
                }
            }
            IExternalPositionsManager(extPositionManager).addExternalPosition(address(this), AdapterInterface(adapter).externalProtocol(), assets[i], amounts[i]);
            unchecked {
                i++;
            }
        }
    }

    function exit(address adapter, bytes calldata data) external override onlyRole(STRATEGY_OPERATOR_ROLE){
        AdapterInterface(adapter).exit(data);
    }


    function harvest() external onlyRole(COMPTROLLER_ROLE){
    
    }

    function sellAllRewardToken() external onlyRole(COMPTROLLER_ROLE){
        
    }

    function strategyNAV() public view override returns(uint256){
        return 0;
    }
}