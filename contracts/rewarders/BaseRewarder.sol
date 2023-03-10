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

import {IRewarder} from "../interfaces/IRewarder.sol";
import {IWooStakingManager} from "../interfaces/IWooStakingManager.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";

abstract contract BaseRewarder is IRewarder, BaseAdminOperation {
    event SetRewardPerBlockOnRewarder(uint256 rewardPerBlock);
    address public immutable rewardToken; // reward token
    uint256 public accTokenPerShare;
    uint256 public rewardPerBlock; // emission rate of reward
    uint256 public lastRewardBlock; // last distribution block

    uint256 totalRewardClaimable = 0;

    IWooStakingManager public stakingManager;

    mapping(address => uint256) public rewardDebt; // reward debt
    mapping(address => uint256) public rewardClaimable; // shadow harvested reward

    constructor(address _rewardToken, address _stakingManager) {
        rewardToken = _rewardToken;
        stakingManager = IWooStakingManager(_stakingManager);
        lastRewardBlock = block.number;
        setAdmin(_stakingManager, true);
    }

    modifier onlyStakingManager() {
        require(_msgSender() == address(stakingManager), "BaseRewarder: !stakingManager");
        _;
    }

    function totalWeight() public view virtual returns (uint256 weightAmount);

    function weight(address _user) public view virtual returns (uint256 rewardAmount);

    function _claim(address _user, address _to) internal virtual returns (uint256 rewardAmount);

    function pendingReward(address _user) external view returns (uint256 rewardAmount) {
        uint256 _totalWeight = totalWeight();

        uint256 _tokenPerShare = accTokenPerShare;
        if (block.number > lastRewardBlock && _totalWeight != 0) {
            uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
            _tokenPerShare += (rewards * 1e18) / _totalWeight;
        }

        uint256 newUserReward = (weight(_user) * _tokenPerShare) / 1e18 - rewardDebt[_user];
        return rewardClaimable[_user] + newUserReward;
    }

    function allPendingReward() external view returns (uint256 rewardAmount) {
        return (block.number - lastRewardBlock) * rewardPerBlock;
    }

    function claim(address _user) external onlyAdmin returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _user);
        emit ClaimOnRewarder(_user, _user, rewardAmount);
    }

    function claim(address _user, address _to) external onlyAdmin returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _to);
        emit ClaimOnRewarder(_user, _to, rewardAmount);
    }

    function setStakingManager(address _manager) external onlyOwner {
        stakingManager = IWooStakingManager(_manager);
        emit SetStakingManagerOnRewarder(_manager);
    }

    // clear and settle the reward
    // Update fields: accTokenPerShare, lastRewardBlock
    function updateReward() public {
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0 || block.number <= lastRewardBlock) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
        accTokenPerShare += (rewards * 1e18) / _totalWeight;
        lastRewardBlock = block.number;
    }

    function updateRewardForUser(address _user) public {
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0 || block.number <= lastRewardBlock) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
        accTokenPerShare += (rewards * 1e18) / _totalWeight;
        lastRewardBlock = block.number;

        uint256 accUserReward = (weight(_user) * accTokenPerShare) / 1e18;
        uint256 newUserReward = accUserReward - rewardDebt[_user];
        rewardClaimable[_user] += newUserReward;
        totalRewardClaimable += newUserReward;
        rewardDebt[_user] = accUserReward;
    }

    function clearRewardToDebt(address _user) public onlyStakingManager {
        rewardDebt[_user] = (weight(_user) * accTokenPerShare) / 1e18;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyAdmin {
        updateReward();
        rewardPerBlock = _rewardPerBlock;
        emit SetRewardPerBlockOnRewarder(_rewardPerBlock);
    }
}
