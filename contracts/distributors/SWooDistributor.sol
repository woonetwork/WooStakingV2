// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IRewardDistributor.sol";
import "../interfaces/IRewardTracker.sol";
import "../dependencies/Governable.sol";

contract SWooRewardDistributor is IRewardDistributor, ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;

    address public admin;
    address public rewardTracker;
    address public override rewardToken;
    uint256 public override tokensPerInterval;
    uint256 public lastDistributionTime;

    modifier onlyAdmin() {
        require(_msgSender() == admin, "RewardDistributor: forbidden");
        _;
    }

    constructor(address _rewardToken, address _rewardTracker) {
        rewardToken = _rewardToken;
        rewardTracker = _rewardTracker;
        admin = _msgSender();
    }

    function distribute() external override returns (uint256) {
        require(_msgSender() == rewardTracker, "RewardDistributor: invalid msg.sender");
        uint256 amount = pendingRewards();
        if (amount == 0) {
            return 0;
        }

        lastDistributionTime = block.timestamp;

        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }

        IERC20(rewardToken).safeTransfer(_msgSender(), amount);

        emit Distribute(amount);
        return amount;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function setAdmin(address _admin) external onlyGov {
        require(_admin != address(0), "RewardDistributor: invalid address");
        admin = _admin;

        emit AdminSet(admin);
    }

    function setTokensPerInterval(uint256 _amount) external onlyAdmin {
        require(lastDistributionTime != 0, "RewardDistributor: invalid lastDistributionTime");
        IRewardTracker(rewardTracker).updateRewards();
        tokensPerInterval = _amount;
        emit TokensPerIntervalChange(_amount);
    }

    function updateLastDistributionTime() external onlyAdmin {
        lastDistributionTime = block.timestamp;
    }

    function pendingRewards() public view override returns (uint256) {
        uint256 timeDiff = block.timestamp - lastDistributionTime;
        return tokensPerInterval * timeDiff;
    }
}
