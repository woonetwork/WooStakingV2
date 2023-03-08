// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWooStakingManager.sol";

interface IRewardBooster {
    event SetMPRewarderOnRewardBooster(address indexed rewarder);

    function boostRatio(address _user) external view returns (uint256);
}
