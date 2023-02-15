// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./BaseRewarder.sol";

import "../interfaces/IRewardBooster.sol";

contract MpRewarder is BaseRewarder {
    IRewardBooster public booster;

    constructor(address _rewardToken, address _stakingManager) BaseRewarder(_rewardToken, _stakingManager) {}

    function totalWeight() public view override returns (uint256) {
        return stakingManager.wooTotalBalance();
    }

    function weight(address _user) public view override returns (uint256) {
        // TODO: weight(user) is legic to be greater than total weight;
        // double check it works on reward claim!

        uint256 ratio = booster.boostRatio(_user);
        uint256 wooBal = stakingManager.wooBalance(_user);
        return ratio == 0 ? wooBal : (wooBal * ratio) / 1e18;
    }

    function _claim(address _user, address _to) internal override returns (uint256 rewardAmount) {
        require(address(stakingManager) == _to, "RESTRICTED_TO_STAKING_MANAGER");
        updateRewardForUser(_user);
        rewardAmount = rewardClaimable[_user];
        rewardClaimable[_user] = 0;
        totalRewardClaimable -= rewardAmount;
    }

    function setBooster(address _booster) external onlyOwner {
        booster = IRewardBooster(_booster);
    }
}
