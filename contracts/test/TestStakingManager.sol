// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/IWooStakingManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

contract TestStakingManager is IWooStakingManager, Ownable, Pausable, ReentrancyGuard {
    uint256 public wooTotalBalance;
    mapping(address => uint256) public wooBalance;
    mapping(address => uint256) public mpBalance;

    address public immutable woo;
    address public immutable mp;

    constructor(address _woo, address _mp) {
        woo = _woo;
        mp = _mp;
    }

    // 权重: have a better name
    function userBalance(address _user) external view returns (uint256) {
        return wooBalance[_user] + mpBalance[_user];
    }

    function stakeWoo(address _user, uint256 _amount) public  {
        wooBalance[_user] += _amount;
        wooTotalBalance += _amount;
    }

    function unstakeWoo(address _user, uint256 _amount) external {}

    function stakeMP(address _user, uint256 _amount) external {}

    function unstakeMP(address _user, uint256 _amount) external {}


    function totalBalance() external pure returns (uint256) {
        return 1000;
    }

    function compoundMP(address _user) external {}

    function compoundRewards(address _user) external {}

    function compoundAll(address _user) external {}
}