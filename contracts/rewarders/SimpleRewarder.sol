// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BaseRewarder.sol";

contract SimpleRewarder is BaseRewarder {
    constructor(address _rewardToken, address _stakingManager) BaseRewarder(_rewardToken, _stakingManager) {}

    function totalWeight() public view override returns (uint256) {
        return stakingManager.totalBalance();
    }

    function weight(address _user) public view override returns (uint256) {
        return stakingManager.totalBalance(_user);
    }
}
