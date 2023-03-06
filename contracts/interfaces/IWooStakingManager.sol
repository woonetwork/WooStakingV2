// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWooStakingManager {
    /* ----- Events ----- */

    event StakeWooOnStakingManager(address indexed user, uint256 amount);
    event UnstakeWooOnStakingManager(address indexed user, uint256 amount);
    event AddMPOnStakingManager(address indexed user, uint256 amount);
    event CompoundMPOnStakingManager(address indexed user);
    event CompoundRewardsOnStakingManager(address indexed user);
    event CompoundAllOnStakingManager(address indexed user);
    event SetMPRewarderOnStakingManager(address indexed rewarder);
    event SetWooPPOnStakingManager(address indexed wooPP);
    event SetStakingProxyOnStakingManager(address indexed stakingProxy);
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
}
