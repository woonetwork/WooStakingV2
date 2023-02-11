// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWooStakingManager.sol";

interface IRewardBooster {
    function boostRatio(address _user) external returns (uint256);
}
