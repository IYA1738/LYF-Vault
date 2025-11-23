//SPDX-License-Identifier:MIT
pragma solidity >= 0.8.0 < 0.9.0;

import "contracts/release/Strategies/IStrategyBase.sol";
import "contracts/release/Strategies/StrategyBaseLayout.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

abstract contract StrategyBase is IStrategyBase,Initializable, StrategyBaseLayout, AccessControlUpgradeable{
    using SafeCast for uint256;

    bytes32 internal immutable COMPTROLLER_ROLE = keccak256("COMPTROLLER_ROLE");
    bytes32 internal immutable STRATEGY_OPERATOR_ROLE = keccak256("STRATEGY_OPERATOR_ROLE");
    bytes32 internal immutable POLICY_MANAGER_ROLE = keccak256("POLICY_MANAGER_ROLE");

    uint256 internal constant SECONDS_IN_YEAR = 31557600; // 60*60*24*365.25
    uint256 internal constant BPS = 10_000;

    event Shutdown(address strategy);
    event UnShutdown(address strategy);
    event SetTakeProfitBps(address indexed strategy, uint16 takeProfitBps);
    event SetStopLossBps(address indexed strategy, uint16 stopLossBps);
    event SetUsingStrategyFeeRateBps(address indexed strategy, uint16 usingStrategyFeeRateBps);
    event SetPerformanceFeeRateBps(address indexed strategy, uint16 performanceFeeRateBps);
    event SetMaxSlippageBps(address indexed strategy, uint16 maxSlippageBps);
    event SetStrategyOperator(address oldStrategyOperator, address newStrategyOperator);
    event SetAdapterWhiteList(address adapter, bool isWhiteList);

    error InvalidAdapter(address adapter);

    function __init_StrategyBase(
        address _comptroller,
        address _strategyOperator,
        address _policyManager,
        uint16 _maxSlippageBps,
        uint16 _takeProfitBps,
        uint16 _stopLossBps,
        uint16 _performanceFeeRateBps,
        uint16 _usingStrategyFeeRateBps
    ) external onlyInitializing {
        StrategyBaseLayoutSlot storage $ = layout();
        $ = StrategyBaseLayoutSlot({
            pnl: 0,
            comptroller: _comptroller,
            lastReport: block.timestamp.toUint48(),
            strategyCreatedTime: block.timestamp.toUint48(),
            strategyOperator: _strategyOperator,
            takeProfitBps: _takeProfitBps,
            stopLossBps: _stopLossBps,
            usingStrategyFeeRateBps: _usingStrategyFeeRateBps,
            performanceFeeRateBps: _performanceFeeRateBps,
            policyManager: _policyManager,
            maxSlippageBps: _maxSlippageBps,
            isShutdown: false
        });

        _grantRole(COMPTROLLER_ROLE, $.comptroller);
        _grantRole(STRATEGY_OPERATOR_ROLE, $.strategyOperator);
        _grantRole(POLICY_MANAGER_ROLE, $.policyManager);

    }

    function strategyNAV() public virtual override returns(uint256){
        
    }

    function setAdapterWhiteList(address adapter, bool isWhiteList) external onlyRole(COMPTROLLER_ROLE){
        if(adapter == address(0)){
            revert InvalidAdapter(adapter);
        }
        StrategyBaseLayoutSlot storage $ = layout();
        $.whiteListAdapters[adapter] = isWhiteList;
        emit SetAdapterWhiteList(adapter, isWhiteList);
    }

    function setStrategyOperator(address newOperator) external onlyRole(COMPTROLLER_ROLE){
        StrategyBaseLayoutSlot storage $ = layout();
        _revokeRole(STRATEGY_OPERATOR_ROLE, $.strategyOperator);
        _grantRole(STRATEGY_OPERATOR_ROLE, newOperator);
        address oldStrategyOperator = $.strategyOperator;
        $.strategyOperator = newOperator;
        emit SetStrategyOperator(oldStrategyOperator, newOperator);
    }

    function setPerformanceFeeRateBps(uint16 _performanceFeeRateBps) external onlyRole(COMPTROLLER_ROLE){
        StrategyBaseLayoutSlot storage $ = layout();
        $.performanceFeeRateBps = _performanceFeeRateBps;
        emit SetPerformanceFeeRateBps(msg.sender, _performanceFeeRateBps);
    }

    function setUsingStrategyFeeRateBps(uint16 _usingStrategyFeeRateBps) external onlyRole(COMPTROLLER_ROLE){
        StrategyBaseLayoutSlot storage $ = layout();
        $.usingStrategyFeeRateBps = _usingStrategyFeeRateBps;
        emit SetUsingStrategyFeeRateBps(msg.sender, _usingStrategyFeeRateBps);
    }

    function setMaxSlippageBps(uint16 _maxSlippageBps) external onlyRole(STRATEGY_OPERATOR_ROLE){
        StrategyBaseLayoutSlot storage $ = layout();
        $.maxSlippageBps = _maxSlippageBps;
        emit SetMaxSlippageBps(msg.sender, _maxSlippageBps);
    }

    function setTakeProfitBps(uint16 _takeProfitBps) external onlyRole(STRATEGY_OPERATOR_ROLE){
        StrategyBaseLayoutSlot storage $ = layout();
        $.takeProfitBps = _takeProfitBps;
        emit SetTakeProfitBps(msg.sender, _takeProfitBps);
    }

    function setStopLossBps(uint16 _stopLossBps) external onlyRole(STRATEGY_OPERATOR_ROLE){
        StrategyBaseLayoutSlot storage $ = layout();
        $.stopLossBps = _stopLossBps;
        emit SetStopLossBps(msg.sender, _stopLossBps);
    }

    function enableStrategy() external onlyRole(STRATEGY_OPERATOR_ROLE){
        StrategyBaseLayoutSlot storage $ = layout();
        $.isShutdown = !$.isShutdown;
        if($.isShutdown){
            emit UnShutdown(msg.sender);
        }else{
            emit Shutdown(msg.sender);
        }
    }
}