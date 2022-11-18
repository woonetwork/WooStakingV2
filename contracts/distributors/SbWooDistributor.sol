// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IBonusDistributor.sol";
import "../interfaces/IRewardTracker.sol";
import "../dependencies/Governable.sol";

contract SbWooBonusDistributor is
    IBonusDistributor,
    ReentrancyGuard,
    Governable
{
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant BONUS_DURATION = 365 days;

    address public admin;
    address public rewardTracker;
    address public override rewardToken;
    uint256 public override tokensPerInterval;
    uint256 public lastDistributionTime;
    uint256 public bonusMultiplierBasisPoints;

    modifier onlyAdmin() {
        require(_msgSender() == admin, "BonusDistributor: forbidden");
        _;
    }

    constructor(address _rewardToken, address _rewardTracker) {
        rewardToken = _rewardToken;
        rewardTracker = _rewardTracker;
        admin = _msgSender();
    }

    function distribute() external override returns (uint256) {
        require(
            _msgSender() == rewardTracker,
            "BonusDistributor: invalid msg.sender"
        );
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

    function boostReward(uint256 amount) external override {
        require(
            _msgSender() == rewardTracker,
            "BonusDistributor: invalid msg.sender"
        );

        if (amount == 0) {
            return;
        }
        IERC20(rewardToken).safeTransfer(_msgSender(), amount);
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function updateLastDistributionTime() external onlyAdmin {
        lastDistributionTime = block.timestamp;
    }

    function setAdmin(address _admin) external onlyGov {
        require(_admin != address(0), "RewardDistributor: invalid address");
        admin = _admin;

        emit AdminSet(admin);
    }

    function setBonusMultiplier(uint256 _bonusMultiplierBasisPoints)
        external
        onlyAdmin
    {
        require(
            lastDistributionTime != 0,
            "BonusDistributor: invalid lastDistributionTime"
        );
        IRewardTracker(rewardTracker).updateRewards();
        bonusMultiplierBasisPoints = _bonusMultiplierBasisPoints;
        emit BonusMultiplierChange(_bonusMultiplierBasisPoints);
    }

    function pendingRewards() public view override returns (uint256) {
        uint256 timeDiff = block.timestamp - lastDistributionTime;
        uint256 supply = IERC20(rewardTracker).totalSupply();

        return
            (timeDiff * supply * bonusMultiplierBasisPoints) /
            BASIS_POINTS_DIVISOR /
            BONUS_DURATION;
    }
}
