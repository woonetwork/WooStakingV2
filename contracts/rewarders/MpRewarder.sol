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

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IRewardBooster} from "../interfaces/IRewardBooster.sol";
import {IRewarder} from "../interfaces/IRewarder.sol";
import {IWooStakingManager} from "../interfaces/IWooStakingManager.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";

contract MpRewarder is IRewarder, BaseAdminOperation, ReentrancyGuard {
    event SetRewardRateOnRewarder(uint256 rate);
    event SetBoosterOnRewarder(address indexed booster);

    uint256 public accTokenPerShare; // accumulated reward token per share.
    uint256 public immutable tokenPerShareDecimal; //  decimal of accTokenPerShare.
    uint256 public rewardRate; // emission rate of reward. e.g. 10000th, 100: 1%, 5000: 50%
    uint256 public lastRewardTs; // last distribution block

    IRewardBooster public booster;

    uint256 totalRewardClaimable = 0;

    IWooStakingManager public stakingManager;

    mapping(address => uint256) public rewardDebt; // reward debt
    mapping(address => uint256) public rewardClaimable; // shadow harvested reward

    constructor(address _stakingManager) {
        tokenPerShareDecimal = 1e18;
        stakingManager = IWooStakingManager(_stakingManager);
        lastRewardTs = block.timestamp;
        setAdmin(_stakingManager, true);
    }

    modifier onlyStakingManager() {
        require(_msgSender() == address(stakingManager), "MpRewarder: !stakingManager");
        _;
    }

    function rewardToken() external pure returns (address) {
        return address(0x0);
    }

    // --------------------- Business Functions --------------------- //

    function pendingReward(address _user) external view returns (uint256 rewardAmount) {
        uint256 _totalWeight = totalWeight();
        uint256 _tokenPerShare = accTokenPerShare;

        if (_totalWeight != 0) {
            uint256 rewards = ((block.timestamp - lastRewardTs) * _totalWeight * rewardRate) / (10000 * 365 days);
            _tokenPerShare += (rewards * tokenPerShareDecimal) / _totalWeight;
        }

        uint256 newUserReward = (weight(_user) * _tokenPerShare) / tokenPerShareDecimal - rewardDebt[_user];
        return rewardClaimable[_user] + newUserReward;
    }

    function allPendingReward() external view returns (uint256 rewardAmount) {
        return ((block.timestamp - lastRewardTs) * totalWeight() * rewardRate) / (10000 * 365 days);
    }

    function claim(address _user) external onlyAdmin returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _user);
    }

    // NOTE: claiming to other address only works for compouding rewards
    function claim(address _user, address _to) external onlyStakingManager returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _to);
    }

    function _claim(address _user, address _to) internal returns (uint256 rewardAmount) {
        updateRewardForUser(_user);
        rewardAmount = rewardClaimable[_user];
        rewardClaimable[_user] = 0;
        totalRewardClaimable -= rewardAmount;
        stakingManager.addMP(_to, rewardAmount);
        emit ClaimOnRewarder(_user, _to, rewardAmount);
    }

    // clear and settle the reward
    // Update fields: accTokenPerShare, lastRewardTs
    function updateReward() public nonReentrant {
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0) {
            lastRewardTs = block.timestamp;
            return;
        }

        uint256 rewards = ((block.timestamp - lastRewardTs) * _totalWeight * rewardRate) / (10000 * 365 days);
        accTokenPerShare += (rewards * tokenPerShareDecimal) / _totalWeight;
        lastRewardTs = block.timestamp;
    }

    function updateRewardForUser(address _user) public nonReentrant {
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0) {
            lastRewardTs = block.timestamp;
            return;
        }

        uint256 rewards = ((block.timestamp - lastRewardTs) * _totalWeight * rewardRate) / (10000 * 365 days);
        accTokenPerShare += (rewards * tokenPerShareDecimal) / _totalWeight;
        lastRewardTs = block.timestamp;

        uint256 accUserReward = (weight(_user) * accTokenPerShare) / tokenPerShareDecimal;
        uint256 newUserReward = accUserReward - rewardDebt[_user];
        rewardClaimable[_user] += newUserReward;
        totalRewardClaimable += newUserReward;

        // NOTE: clear all rewards to debt
        rewardDebt[_user] = accUserReward;
    }

    function clearRewardToDebt(address _user) public {
        require(
            _msgSender() == address(stakingManager) || _msgSender() == address(booster),
            "MpRewarder: !stakingManager and !booster"
        );
        rewardDebt[_user] = (weight(_user) * accTokenPerShare) / tokenPerShareDecimal;
    }

    function boostedRewardRate(address _user) external view returns (uint256) {
        return (rewardRate * booster.boostRatio(_user)) / booster.base();
    }

    function totalWeight() public view returns (uint256) {
        // CAUTION: total balance not counting boost ratio
        return stakingManager.wooTotalBalance();
    }

    function weight(address _user) public view returns (uint256) {
        uint256 ratio = booster.boostRatio(_user);
        uint256 wooBal = stakingManager.wooBalance(_user);
        return ratio == 0 ? wooBal : (wooBal * ratio) / booster.base();
    }

    // --------------------- Admin Functions --------------------- //

    function setStakingManager(address _manager) external onlyAdmin {
        if (address(stakingManager) != address(0)) {
            setAdmin(address(stakingManager), false);
        }
        stakingManager = IWooStakingManager(_manager);
        setAdmin(_manager, true);
        emit SetStakingManagerOnRewarder(_manager);
    }

    function setRewardRate(uint256 _rate) external onlyAdmin {
        updateReward();
        rewardRate = _rate;
        emit SetRewardRateOnRewarder(_rate);
    }

    function setBooster(address _booster) external onlyAdmin {
        updateReward();
        booster = IRewardBooster(_booster);
        emit SetBoosterOnRewarder(_booster);
    }
}
