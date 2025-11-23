//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

abstract contract StrategyBaseLayout{
    bytes32 internal constant STRATEGY_BASE_LAYOUT_SLOT = bytes32(uint256(keccak256("iya.strategy.base.layout")) - 1);
    struct StrategyBaseLayoutSlot{
        //Slot 0
        int256 pnl;

        //Slot 1
        address comptroller;
        uint48 lastReport;
        uint48 strategyCreatedTime;
        
        //Slot 2
        address strategyOperator;
        uint16 takeProfitBps;
        uint16 stopLossBps;
        uint16 usingStrategyFeeRateBps;
        uint16 performanceFeeRateBps;

        //Slot 3
        address policyManager;
        uint16 maxSlippageBps;
        bool isShutdown;

        //Slot 4
        mapping(address => bool) whiteListAdapters;
    }

    function layout() internal view returns(StrategyBaseLayoutSlot storage $){
       bytes32 slot = STRATEGY_BASE_LAYOUT_SLOT;
        assembly {
            $.slot := slot
        }
    }
}