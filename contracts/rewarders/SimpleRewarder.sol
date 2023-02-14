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

    function _claim(address _user, address _to) internal override returns (uint256 rewardAmount) {
        updateRewardForUser(_user);
        rewardAmount = rewardClaimable[_user];
        TransferHelper.safeTransfer(rewardToken, _to, rewardAmount);
        totalRewardClaimable -= rewardAmount;
        rewardClaimable[_user] = 0;
    }
}
