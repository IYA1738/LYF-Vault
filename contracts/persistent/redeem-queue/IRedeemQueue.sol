//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IRedeemQueue{
    struct RedeemRequest{
        address user;
        uint96 sharesAmount;
        address token;
        uint96 assetsValueWhenRedeemed;
    }

    function requestRedeemQueue(RedeemRequest memory redeemRequest) external;
}