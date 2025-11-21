//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IFeeAccounting{
    enum ChargeType{
        UserDeposit,
        UserRedeem,
        PushToStrategy,
        PullFromStrategy,
        FundManageFee
    }

    function calFee(address _target, uint256 _amount) external view returns(uint256 fee_);

    function setFeeRate(address target, uint256 feeRate) external;

    function getFeeRate(address target) external view returns(uint256);

    mapping(address => uint256) public feeRates;
}