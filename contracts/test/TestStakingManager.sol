// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/IWooStakingManager.sol";
import {IRewarder} from "../interfaces/IRewarder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";

contract TestStakingManager is IWooStakingManager, BaseAdminOperation {
    mapping(address => uint256) public wooBalance;
    mapping(address => uint256) public mpBalance;
    uint256 public mpTotalBalance;
    uint256 public wooTotalBalance;
    IRewarder public mpRewarder; // Record and distribute MP rewards

    modifier onlyMpRewarder() {
        require(address(mpRewarder) == msg.sender, "RESTRICTED_TO_MP_REWARDER");
        _;
    }

    function setMPRewarder(address _rewarder) external onlyAdmin {
        mpRewarder = IRewarder(_rewarder);
        require(address(IRewarder(_rewarder).stakingManager()) == address(this));
    }

    // 权重: have a better name
    function totalBalance(address _user) external view returns (uint256) {
        return wooBalance[_user] + mpBalance[_user];
    }

    function stakeWoo(address _user, uint256 _amount) public  {
        wooBalance[_user] += _amount;
        wooTotalBalance += _amount;
    }

    function unstakeWoo(address _user, uint256 _amount) external {}

    function stakeMP(address _user, uint256 _amount) external {}

    function unstakeMP(address _user, uint256 _amount) external {}


    function totalBalance() external view returns (uint256) {
        return wooTotalBalance + mpTotalBalance;
    }

    function compoundMP(address _user) external {}

    function addMP(address _user, uint256 _amount) external onlyMpRewarder {
        mpBalance[_user] += _amount;
        mpTotalBalance += _amount;
    }

    function compoundRewards(address _user) external {}

    function compoundAll(address _user) external {}
}