//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IFeeHandler{
    enum ChargeType{
        UserDeposit,
        UserRedeem,
        PushToStrategy,
        FundManageFee
    }
    function getProtocolFee(address _vaultProxy) external view returns(uint256);
    function feePayingHook(ChargeType _type, address _vaultProxy, address token, uint256 amount) external returns(uint256);
    function previewFee(ChargeType _type, address _vaultProxy, uint256 amount) external view returns(uint256);
}