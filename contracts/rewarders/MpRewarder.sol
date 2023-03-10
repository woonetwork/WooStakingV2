// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import {IRewardBooster} from "../interfaces/IRewardBooster.sol";
import {IRewarder} from "../interfaces/IRewarder.sol";
import {IWooStakingManager} from "../interfaces/IWooStakingManager.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";

contract MpRewarder is IRewarder, BaseAdminOperation {
    event SetRewardRateOnRewarder(uint256 rate);
    event SetBoosterOnRewarder(address indexed booster);

    address public immutable rewardToken; // reward token
    uint256 public accTokenPerShare;
    uint256 public rewardRate; // emission rate of reward. e.g. 10000th, 100: 1%, 5000: 50%
    uint256 public lastRewardTs; // last distribution block

    IRewardBooster public booster;

    uint256 totalRewardClaimable = 0;

    IWooStakingManager public stakingManager;

    mapping(address => uint256) public rewardDebt; // reward debt
    mapping(address => uint256) public rewardClaimable; // shadow harvested reward

    constructor(address _rewardToken, address _stakingManager) {
        rewardToken = _rewardToken;
        stakingManager = IWooStakingManager(_stakingManager);
        lastRewardTs = block.timestamp;
        setAdmin(_stakingManager, true);
    }

    modifier onlyStakingManager() {
        require(_msgSender() == address(stakingManager), "MpRewarder: !stakingManager");
        _;
    }

    function totalWeight() public view returns (uint256) {
        return stakingManager.wooTotalBalance();
    }

    function weight(address _user) public view returns (uint256) {
        uint256 ratio = booster.boostRatio(_user);
        uint256 wooBal = stakingManager.wooBalance(_user);
        return ratio == 0 ? wooBal : (wooBal * ratio) / booster.base();
    }

    function _claim(address _user, address _to) internal returns (uint256 rewardAmount) {
        updateRewardForUser(_user);
        rewardAmount = rewardClaimable[_user];
        stakingManager.addMP(_to, rewardAmount);
        rewardClaimable[_user] = 0;
        totalRewardClaimable -= rewardAmount;
    }

    function setBooster(address _booster) external onlyOwner {
        booster = IRewardBooster(_booster);
        emit SetBoosterOnRewarder(_booster);
    }

    function pendingReward(address _user) external view returns (uint256 rewardAmount) {
        uint256 _totalWeight = totalWeight();

        uint256 _tokenPerShare = accTokenPerShare;
        if (block.timestamp > lastRewardTs && _totalWeight != 0) {
            // 1 year = 31,536,000 seconds
            uint256 rewards = ((block.timestamp - lastRewardTs) * _totalWeight * rewardRate) / 10000 / 31536000;
            _tokenPerShare += (rewards * 1e18) / _totalWeight;
        }

        uint256 newUserReward = (weight(_user) * _tokenPerShare) / 1e18 - rewardDebt[_user];
        return rewardClaimable[_user] + newUserReward;
    }

    function allPendingReward() external view returns (uint256 rewardAmount) {
        // 1 year = 31,536,000 seconds
        return ((block.timestamp - lastRewardTs) * totalWeight() * rewardRate) / 10000 / 31536000;
    }

    function claim(address _user) external onlyAdmin returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _user);
        emit ClaimOnRewarder(_user, _user, rewardAmount);
    }

    function claim(address _user, address _to) external onlyAdmin returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _to);
        emit ClaimOnRewarder(_user, _to, rewardAmount);
    }

    function setStakingManager(address _manager) external onlyAdmin {
        stakingManager = IWooStakingManager(_manager);
        emit SetStakingManagerOnRewarder(_manager);
    }

    function setRewardRate(uint256 _rate) external onlyAdmin {
        updateReward();
        rewardRate = _rate;
        emit SetRewardRateOnRewarder(_rate);
    }

    // clear and settle the reward
    // Update fields: accTokenPerShare, lastRewardTs
    function updateReward() public {
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0 || block.timestamp <= lastRewardTs) {
            lastRewardTs = block.timestamp;
            return;
        }

        uint256 rewards = ((block.timestamp - lastRewardTs) * _totalWeight * rewardRate) / 10000 / 31536000;
        accTokenPerShare += (rewards * 1e18) / _totalWeight;
        lastRewardTs = block.timestamp;
    }

    function updateRewardForUser(address _user) public {
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0 || block.timestamp <= lastRewardTs) {
            lastRewardTs = block.timestamp;
            return;
        }

        uint256 rewards = ((block.timestamp - lastRewardTs) * _totalWeight * rewardRate) / 10000 / 31536000;
        accTokenPerShare += (rewards * 1e18) / _totalWeight;
        lastRewardTs = block.timestamp;

        uint256 accUserReward = (weight(_user) * accTokenPerShare) / 1e18;
        uint256 newUserReward = accUserReward - rewardDebt[_user];
        rewardClaimable[_user] += newUserReward;
        totalRewardClaimable += newUserReward;
        rewardDebt[_user] = accUserReward;
    }

    function clearRewardToDebt(address _user) public onlyStakingManager {
        rewardDebt[_user] = (weight(_user) * accTokenPerShare) / 1e18;
    }

    function boostedRewardRate(address _user) external view returns (uint256) {
        return (rewardRate * booster.boostRatio(_user)) / booster.base();
    }
}
