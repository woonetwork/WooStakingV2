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

contract SimpleRewarder is IRewarder, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public RewardAccum;

    uint256 public accTokenPerShare;

    IWooStakingManager public stakingManager;

    address public rewardToken; // reward token
    uint256 public rewardPerBlock; // emission rate of reward
    uint256 public lastRewardBlock; // last distribution block

    constructor(address _rewardToken, address _stakingManager) {
        rewardToken = _rewardToken;
        stakingManager = IWooStakingManager(_stakingManager);
    }

    function pendingReward(address _user) external view override returns (uint256 rewardAmount) {
        uint256 totalBalance = stakingManager.totalBalance();

        uint256 accNew = accTokenPerShare;
        if (block.number > lastRewardBlock && totalBalance != 0) {
            uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
            accNew += (rewards * 1e18) / totalBalance;
        }

        rewardAmount = (stakingManager.userBalance(_user) * accNew) / 1e18 - rewardDebt[_user];
    }

    function claim(address _user) external returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _user); // TODO: double check the _user is the receiver address
    }

    function claim(address _user, address _to) external returns (uint256 rewardAmount) {
        rewardAmount = _claim(_user, _to);
    }

    function _claim(address _user, address _to) private returns (uint256 rewardAmount) {
        updateReward();

        rewardAmount = (stakingManager.userBalance(_user) * accTokenPerShare) / 1e18 - rewardDebt[_user];

        rewardDebt[_user] += rewardAmount;

        TransferHelper.safeTransfer(rewardToken, _to, rewardAmount);
    }

    function setStakingManager(address _manager) external onlyOwner {
        stakingManager = IWooStakingManager(_manager);
    }

    function setRewardPerBlock(uint256 _amount) external onlyOwner {
        rewardPerBlock = _amount;
    }

    // clear and settle the reward
    // Update fields: accTokenPerShare, lastRewardBlock
    function updateReward() public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        uint256 totalBalance = stakingManager.totalBalance();
        if (totalBalance > 0) {
            uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
            accTokenPerShare += (rewards * 1e18) / totalBalance;
            lastRewardBlock = block.number;
        }
    }

    function state() external view returns (uint256 _lastRewardBlock, uint256 _accTokenPerShare) {
        _lastRewardBlock = lastRewardBlock;
        _accTokenPerShare = accTokenPerShare;
    }

    // TODO: settle the user's rewards
    function updateRewardForUser(address _user) public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        // shadow harvest for _user
        RewardAccum[_user] = uint256(100); // TODO: finish it

        uint256 totalBalance = stakingManager.totalBalance();
        if (totalBalance > 0) {
            uint256 rewards = (block.number - lastRewardBlock) * rewardPerBlock;
            accTokenPerShare += (rewards * 1e18) / totalBalance;
            lastRewardBlock = block.number;
        }
    }
}
