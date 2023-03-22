// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWooStakingLocal {
    /* ----- Events ----- */

    event StakeOnLocal(address indexed user, uint256 amount);
    event UnstakeOnLocal(address indexed user, uint256 amount);
    event SetAutoCompoundOnLocal(address indexed user, bool flag);
    event CompoundMPOnLocal(address indexed user);
    event CompoundAllOnLocal(address indexed user);

    /* ----- State Variables ----- */

    function want() external view returns (IERC20);

    function balances(address user) external view returns (uint256 balance);

    /* ----- Functions ----- */

    function stake(uint256 _amount) external;

    function stake(address _user, uint256 _amount) external;

    function unstake(uint256 _amount) external;

    function unstakeAll() external;

    function setAutoCompound(bool _flag) external;

    function compoundMP() external;

    function compoundAll() external;
}
