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

    address public rewardToken;

    IWooStakingManager public stakingManager;

    constructor(address _rewardToken, address _stakingManager) {
        rewardToken = _rewardToken;
        stakingManager = IWooStakingManager(_stakingManager);
    }

    function pendingReward(address _user) external returns (uint256 rewardAmount) {}

    function claim(address _user) external returns (uint256 rewardAmount) {}

    function claim(address _user, address _to) external returns (uint256 rewardAmount) {}

    function setStakingManager(address _manager) external onlyOwner {
        stakingManager = IWooStakingManager(_manager);
    }
}
