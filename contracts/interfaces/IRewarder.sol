// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWooStakingManager.sol";

interface IRewarder {
    event ClaimOnRewarder(address indexed from, address indexed to, uint256 amount);
    event SetStakingManagerOnRewarder(address indexed manager);

    function rewardToken() external view returns (address);

    function stakingManager() external view returns (IWooStakingManager);

    function pendingReward(address _user) external view returns (uint256 rewardAmount);

    function claim(address _user) external returns (uint256 rewardAmount);

    function claim(address _user, address _to) external returns (uint256 rewardAmount);

    function setStakingManager(address _manager) external;

    function updateReward() external;

    function updateRewardForUser(address _user) external;

    function clearRewardToDebt(address _user) external;
}
