// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import "../interfaces/IRewarder.sol";
import "../interfaces/IWooStakingManager.sol";
import "../util/TransferHelper.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BaseRewarder is IRewarder, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public rewardAccum;

    uint256 public accTokenPerShare;

    IWooStakingManager public stakingManager;

    address public rewardToken; // reward token
    uint256 public rewardPerBlock; // emission rate of reward
    uint256 public lastRewardBlock; // last distribution block

    constructor(address _rewardToken, address _stakingManager) {
        rewardToken = _rewardToken;
        stakingManager = IWooStakingManager(_stakingManager);
    }

    function totalWeight() public view virtual returns (uint256 weightAmount) {}

    function weight(address _user) public view virtual returns (uint256 rewardAmount) {}

    function pendingReward(address _user) external view returns (uint256 rewardAmount) {
        uint256 _totalWeight = totalWeight();

        uint256 _tokenPerShare = accTokenPerShare;
        if (block.number > lastRewardBlock && _totalWeight != 0) {
            uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
            _tokenPerShare += (rewards * 1e18) / _totalWeight;
        }

        uint256 newUserReward = (_totalWeight * _tokenPerShare) / 1e18 - rewardDebt[_user];
        return rewardAccum[_user] + newUserReward;
    }

    function claim(address _user) external returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _user); // TODO: double check the _user is the receiver address
    }

    function claim(address _user, address _to) external returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _to);
    }

    function _claim(address _user, address _to) private returns (uint256 rewardAmount) {
        updateRewardForUser(_user);
        rewardAmount = rewardAccum[_user];
        TransferHelper.safeTransfer(rewardToken, _to, rewardAmount);
        rewardAccum[_user] = 0;
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
        uint256 _totalWeight = totalWeight();
        if (_totalWeight == 0 || block.number <= lastRewardBlock) {
            // no deposit, nor no new reward emission, nothing needs to do.
            return;
        }

        uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
        accTokenPerShare += (rewards * 1e18) / _totalWeight;
        lastRewardBlock = block.number;

        uint256 newUserReward = (weight(_user) * accTokenPerShare) / 1e18 - rewardDebt[_user];
        rewardAccum[_user] += newUserReward;
        rewardDebt[_user] = (weight(_user) * accTokenPerShare) / 1e18;
    }
}
