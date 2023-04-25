// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IWooStakingManager {
    /* ----- Events ----- */

    event StakeWooOnStakingManager(address indexed user, uint256 amount);
    event UnstakeWooOnStakingManager(address indexed user, uint256 amount);
    event AddMPOnStakingManager(address indexed user, uint256 amount);
    event CompoundMPOnStakingManager(address indexed user);
    event CompoundRewardsOnStakingManager(address indexed user);
    event CompoundAllOnStakingManager(address indexed user);
    event SetAutoCompoundOnStakingManager(address indexed user, bool flag);
    event SetMPRewarderOnStakingManager(address indexed rewarder);
    event SetWooPPOnStakingManager(address indexed wooPP);
    event SetStakingLocalOnStakingManager(address indexed stakingProxy);
    event SetCompounderOnStakingManager(address indexed compounder);
    event AddRewarderOnStakingManager(address indexed rewarder);
    event RemoveRewarderOnStakingManager(address indexed rewarder);
    event ClaimRewardsOnStakingManager(address indexed user);

    /* ----- State Variables ----- */

    /* ----- Functions ----- */

    function stakeWoo(address _user, uint256 _amount) external;

    function unstakeWoo(address _user, uint256 _amount) external;

    function mpBalance(address _user) external view returns (uint256);

    function wooBalance(address _user) external view returns (uint256);

    function wooTotalBalance() external view returns (uint256);

    function totalBalance(address _user) external view returns (uint256);

    function totalBalance() external view returns (uint256);

    function compoundMP(address _user) external;

    function addMP(address _user, uint256 _amount) external;

    function compoundRewards(address _user) external;

    function compoundAll(address _user) external;

    function compoundAllForUsers(address[] memory _users) external;

    function setAutoCompound(address _user, bool _flag) external;

    function pendingRewards(
        address _user
    ) external view returns (uint256 mpRewardAmount, address[] memory rewardTokens, uint256[] memory amounts);
}
