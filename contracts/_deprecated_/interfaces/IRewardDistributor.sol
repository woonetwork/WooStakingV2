// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IRewardDistributor {
    event AdminSet(address admin);
    event Distribute(uint256 amount);
    event TokensPerIntervalChange(uint256 amount);
    event BonusMultiplierChange(uint256);

    function rewardToken() external view returns (address);

    function tokensPerInterval() external view returns (uint256);

    function pendingRewards() external view returns (uint256);

    function distribute() external returns (uint256);
}
