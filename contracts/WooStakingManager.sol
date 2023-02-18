// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IRewarder} from "./interfaces/IRewarder.sol";
import {IWooPPV2} from "./interfaces/IWooPPV2.sol";
import {IWooStakingManager} from "./interfaces/IWooStakingManager.sol";
import {IWooStakingProxy} from "./interfaces/IWooStakingProxy.sol";

import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {TransferHelper} from "./util/TransferHelper.sol";
import "hardhat/console.sol";

// TODO: emit events
//
contract WooStakingManager is IWooStakingManager, BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) public wooBalance;
    mapping(address => uint256) public mpBalance;
    uint256 public wooTotalBalance;
    uint256 public mpTotalBalance;

    IWooPPV2 public wooPP;
    IWooStakingProxy public stakingProxy;

    address public immutable woo;

    IRewarder public mpRewarder; // Record and distribute MP rewards
    EnumerableSet.AddressSet private rewarders; // Other general rewards (e.g. usdc, eth, op, etc)

    constructor(address _woo, address _wooPP, address _stakingProxy) {
        woo = _woo;
        wooPP = IWooPPV2(_wooPP);
        stakingProxy = IWooStakingProxy(_stakingProxy);
    }

    // --------------------- Business Functions --------------------- //

    function setMPRewarder(address _rewarder) external onlyAdmin {
        mpRewarder = IRewarder(_rewarder);
        require(address(IRewarder(_rewarder).stakingManager()) == address(this));
    }

    function addRewarder(address _rewarder) external onlyAdmin {
        require(address(IRewarder(_rewarder).stakingManager()) == address(this));
        rewarders.add(_rewarder);
    }

    function removeRewarder(address _rewarder) external onlyAdmin {
        rewarders.remove(_rewarder);
    }

    function _updateRewards(address _user) private {
        mpRewarder.updateRewardForUser(_user);
        unchecked {
            for (uint256 i = 0; i < rewarders.length(); ++i) {
                IRewarder(rewarders.at(i)).updateRewardForUser(_user);
            }
        }
    }

    function _updateDebts(address _user) private {
        mpRewarder.updateDebtForUser(_user);
        unchecked {
            for (uint256 i = 0; i < rewarders.length(); ++i) {
                IRewarder(rewarders.at(i)).updateDebtForUser(_user);
            }
        }
    }

    function stakeWoo(address _user, uint256 _amount) public onlyAdmin {
        _updateRewards(_user);
        compoundMP(_user);

        wooBalance[_user] += _amount;
        wooTotalBalance += _amount;

        _updateDebts(_user);
    }

    function unstakeWoo(address _user, uint256 _amount) external onlyAdmin {
        _updateRewards(_user);
        compoundMP(_user);

        uint256 wooPrevBalance = wooBalance[_user];
        wooBalance[_user] -= _amount;
        wooTotalBalance -= _amount;

        _updateDebts(_user);

        // remove the proportional amount of MP tokens, based on amount / wooBalance
        uint256 burnAmount = (mpBalance[_user] * _amount) / wooPrevBalance;
        mpBalance[_user] -= burnAmount;
        mpTotalBalance -= burnAmount;
    }

    function totalBalance(address _user) external view returns (uint256) {
        return wooBalance[_user] + mpBalance[_user];
    }

    function totalBalance() external view returns (uint256) {
        return wooTotalBalance + mpTotalBalance;
    }

    function pendingRewards(
        address _user
    ) external view returns (uint256 mpRewardAmount, address[] memory rewardTokens, uint256[] memory amounts) {
        mpRewardAmount = mpRewarder.pendingReward(_user);

        uint256 length = rewarders.length();
        rewardTokens = new address[](length);
        amounts = new uint256[](length);

        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                IRewarder _rewarder = IRewarder(rewarders.at(i));
                rewardTokens[i] = _rewarder.rewardToken();
                amounts[i] = _rewarder.pendingReward(_user);
            }
        }
    }

    // TODO: add get rewarder array method

    function claimRewards() external {
        _claim(msg.sender);
    }

    function claimRewards(address _user) external onlyAdmin {
        _claim(_user);
    }

    function _claim(address _user) private {
        // compoundMP(_user);

        for (uint256 i = 0; i < rewarders.length(); ++i) {
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            _rewarder.claim(_user);
        }
    }

    function compoundAll(address _user) external onlyAdmin {
        compoundMP(_user);
        compoundRewards(_user);
    }

    function compoundMP(address _user) public onlyAdmin {
        // claim auto updates the reward for the user
        uint256 amount = mpRewarder.claim(_user, address(this));

        // NO need to transfer MP token to self again
        mpBalance[_user] += amount;
        mpTotalBalance += amount;
    }

    function compoundRewards(address _user) public onlyAdmin {
        // TODO: attention! claim triggers updateReward
        uint256 wooAmount = 0;
        address selfAddr = address(this);
        for (uint256 i = 0; i < rewarders.length(); ++i) {
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            uint256 rewardAmount = _rewarder.claim(_user, selfAddr); // claim auto update reward for the user.
            console.log("rewardToken: %s _user: %s, rewardAmount: %s ", _rewarder.rewardToken(), _user, rewardAmount);
            TransferHelper.safeApprove(_rewarder.rewardToken(), address(wooPP), rewardAmount);
            if (_rewarder.rewardToken() != woo) {
                wooAmount += wooPP.swap(_rewarder.rewardToken(), woo, rewardAmount, 0, selfAddr, selfAddr);
            }
        }

        TransferHelper.safeApprove(woo, address(stakingProxy), wooAmount);
        stakingProxy.stake(_user, wooAmount);
        // stakeWoo(_user, wooAmount);
    }

    // --------------------- Admin Functions --------------------- //

    function setWooPP(address _wooPP) external onlyAdmin {
        wooPP = IWooPPV2(_wooPP);
    }

    function setStakingProxy(address _proxy) external onlyAdmin {
        stakingProxy = IWooStakingProxy(_proxy);
    }
}
