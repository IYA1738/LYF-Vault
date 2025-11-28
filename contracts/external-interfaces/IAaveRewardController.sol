// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface IAaveV3RewardsController {
    function claimRewards(address[] calldata _assets, uint256 _amount, address _to, address _rewardToken)
        external
        returns (uint256 amountClaimed_);
}