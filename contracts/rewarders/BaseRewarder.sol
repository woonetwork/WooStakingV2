// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IRewarder} from "../interfaces/IRewarder.sol";
import {IWooStakingManager} from "../interfaces/IWooStakingManager.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";

abstract contract BaseRewarder is IRewarder, BaseAdminOperation {
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

    function claim(address _user) external returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _user); // TODO: double check the _user is the receiver address
    }

    function claim(address _user, address _to) external returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _to);
    }

    function setStakingManager(address _manager) external onlyOwner {
        stakingManager = IWooStakingManager(_manager);
    }

    // clear and settle the reward
    // Update fields: accTokenPerShare, lastRewardBlock
    function updateReward() public {
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0 || block.number <= lastRewardBlock) {
            return;
        }

        uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
        accTokenPerShare += (rewards * 1e18) / _totalWeight;
        lastRewardBlock = block.number;
    }

    // TODO: settle the user's rewards
    function updateRewardForUser(address _user) public {
        updateReward();

        uint256 accUserReward = (weight(_user) * accTokenPerShare) / 1e18;
        uint256 newUserReward = accUserReward - rewardDebt[_user];
        rewardClaimable[_user] += newUserReward;
        totalRewardClaimable += newUserReward;
        rewardDebt[_user] = accUserReward;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        updateReward();
        rewardPerBlock = _rewardPerBlock;
    }
}
