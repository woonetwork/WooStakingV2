// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWooStakingManager.sol";

interface IRewarder {
    function rewardToken() external returns (address);

    function pendingReward(address _user) external returns (uint256 rewardAmount);

    function claim(address _user) external returns (uint256 rewardAmount);

    function claim(address _user, address _to) external returns (uint256 rewardAmount);

    function stakingManager() external returns (IWooStakingManager);

    function setStakingManager(address _manager) external;
}
