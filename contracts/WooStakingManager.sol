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
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IRewarder} from "./interfaces/IRewarder.sol";
import {IWooStakingCompounder} from "./interfaces/IWooStakingCompounder.sol";
import {IWooPPV2} from "./interfaces/IWooPPV2.sol";
import {IWooStakingManager} from "./interfaces/IWooStakingManager.sol";
import {IWooStakingLocal} from "./interfaces/IWooStakingLocal.sol";

import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {TransferHelper} from "./util/TransferHelper.sol";

contract WooStakingManager is IWooStakingManager, BaseAdminOperation, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) public wooBalance;
    mapping(address => uint256) public mpBalance;
    uint256 public wooTotalBalance;
    uint256 public mpTotalBalance;
    EnumerableSet.AddressSet private stakers;

    IWooPPV2 public wooPP;
    IWooStakingLocal public stakingLocal;

    address public immutable woo;

    IRewarder public mpRewarder; // Record and distribute MP rewards
    EnumerableSet.AddressSet private rewarders; // Other general rewards (e.g. usdc, eth, op, etc)

    IWooStakingCompounder public compounder;

    constructor(address _woo) {
        woo = _woo;
    }

    modifier onlyMpRewarder() {
        require(address(mpRewarder) == msg.sender, "RESTRICTED_TO_MP_REWARDER");
        _;
    }

    // --------------------- Business Functions --------------------- //

    function stakeWoo(address _user, uint256 _amount) public onlyAdmin {
        if (_amount == 0) {
            return;
        }

        _updateRewardsForUser(_user);
        mpRewarder.claim(_user); // claim and compound into staking manager

        wooBalance[_user] += _amount;
        wooTotalBalance += _amount;

        _clearRewardsToDebt(_user);

        if (_amount > 0) {
            stakers.add(_user);
        }

        emit StakeWooOnStakingManager(_user, _amount);
    }

    function unstakeWoo(address _user, uint256 _amount) public onlyAdmin {
        if (_amount == 0) {
            return;
        }

        _updateRewardsForUser(_user);
        mpRewarder.claim(_user);

        uint256 wooPrevBalance = wooBalance[_user];
        wooBalance[_user] -= _amount;
        wooTotalBalance -= _amount;

        // When unstaking, remove the proportional amount of MP tokens,
        // based on amount / wooBalance
        uint256 burnAmount = (mpBalance[_user] * _amount) / wooPrevBalance;
        mpBalance[_user] -= burnAmount;
        mpTotalBalance -= burnAmount;

        _clearRewardsToDebt(_user);

        compounder.removeUserIfThresholdFail(_user);

        if (wooBalance[_user] == 0) {
            stakers.remove(_user);
        }

        emit UnstakeWooOnStakingManager(_user, _amount);
    }

    function _updateRewardsForUser(address _user) internal {
        mpRewarder.updateRewardForUser(_user);
        unchecked {
            for (uint256 i = 0; i < rewarders.length(); ++i) {
                IRewarder(rewarders.at(i)).updateRewardForUser(_user);
            }
        }
    }

    function _clearRewardsToDebt(address _user) internal {
        mpRewarder.clearRewardToDebt(_user);
        unchecked {
            for (uint256 i = 0; i < rewarders.length(); ++i) {
                IRewarder(rewarders.at(i)).clearRewardToDebt(_user);
            }
        }
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

    function claimRewards() external nonReentrant {
        address _user = msg.sender;
        // NOTE: manual-claim only works when user disables the auto compounding
        require(!compounder.contains(_user), "WooStakingManager: !COMPOUND");
        _claim(_user);
    }

    function claimRewards(address _user) external onlyAdmin {
        // NOTE: admin forced claim reward can bypass the auto compounding, by design.
        // REMOVED: require(!compounder.contains(_user), "WooStakingManager: !COMPOUND");
        _claim(_user);
    }

    function _claim(address _user) internal {
        for (uint256 i = 0; i < rewarders.length(); ++i) {
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            _rewarder.claim(_user);
        }
        emit ClaimRewardsOnStakingManager(_user);
    }

    function setAutoCompound(address _user, bool _flag) external onlyAdmin {
        if (_flag) {
            compounder.addUserIfThresholdMeet(_user);
        } else {
            compounder.removeUser(_user);
        }
        emit SetAutoCompoundOnStakingManager(_user, _flag);
    }

    function compoundAll(address _user) external onlyAdmin {
        compoundMP(_user);
        compoundRewards(_user);
        emit CompoundAllOnStakingManager(_user);
    }

    function compoundAllForUsers(address[] memory _users) external onlyAdmin {
        uint256 len = _users.length;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                compoundMP(_users[i]);
            }
        }

        uint256[] memory rewards = new uint256[](len);
        address selfAddr = address(this);
        uint256[] memory wooRewards = new uint256[](len);
        uint256 wooTotalAmount = 0;
        uint256 rewarderLen = rewarders.length();
        for (uint256 i = 0; i < rewarderLen; ++i) {
            uint256 totalReward = 0;
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            // claim token
            for (uint256 j = 0; j < len; ++j) {
                uint256 rewardAmount = _rewarder.claim(_users[j], address(wooPP));
                rewards[j] = rewardAmount;
                totalReward += rewardAmount;
            }
            // swap
            uint256 rewarderTotalWoo = 0;
            address rewardToken = _rewarder.rewardToken();
            if (rewardToken == woo) {
                rewarderTotalWoo = totalReward;
            } else {
                rewarderTotalWoo = wooPP.swap(rewardToken, woo, totalReward, 0, selfAddr, selfAddr);
            }
            for (uint256 j = 0; j < len; ++j) {
                wooRewards[j] += (rewarderTotalWoo * rewards[j]) / totalReward;
            }
            wooTotalAmount += rewarderTotalWoo;
        }
        if (wooTotalAmount > 0) {
            TransferHelper.safeApprove(woo, address(stakingLocal), wooTotalAmount);
            stakingLocal.stakeForUsers(_users, wooRewards, wooTotalAmount);
        }
        emit CompoundAllForUsersOnStakingManager(_users, wooRewards);
    }

    function compoundMP(address _user) public onlyAdmin {
        // Caution: since user weight is related to mp balance, force update rewards and debts.
        uint256 i;
        uint256 len = rewarders.length();
        unchecked {
            for (i = 0; i < len; ++i) {
                IRewarder(rewarders.at(i)).updateRewardForUser(_user);
            }
        }

        mpRewarder.claim(_user); // claim MP and restaking to this managaer

        unchecked {
            for (i = 0; i < len; ++i) {
                IRewarder(rewarders.at(i)).clearRewardToDebt(_user);
            }
        }

        emit CompoundMPOnStakingManager(_user);
    }

    function addMP(address _user, uint256 _amount) public onlyMpRewarder {
        mpBalance[_user] += _amount;
        mpTotalBalance += _amount;
        emit AddMPOnStakingManager(_user, _amount);
    }

    function compoundRewards(address _user) public onlyAdmin {
        uint256 wooAmount = 0;
        address selfAddr = address(this);
        uint256 len = rewarders.length();
        for (uint256 i = 0; i < len; ++i) {
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            if (_rewarder.rewardToken() == woo) {
                wooAmount += _rewarder.claim(_user, selfAddr);
            } else {
                // claim and swap to WOO token
                uint256 rewardAmount = _rewarder.claim(_user, address(wooPP));
                if (rewardAmount > 0) {
                    wooAmount += wooPP.swap(_rewarder.rewardToken(), woo, rewardAmount, 0, selfAddr, selfAddr);
                }
            }
        }

        if (wooAmount > 0) {
            TransferHelper.safeApprove(woo, address(stakingLocal), wooAmount);
            stakingLocal.stake(_user, wooAmount);
        }

        emit CompoundRewardsOnStakingManager(_user, wooAmount);
    }

    // --------------------- Admin Maintain Functions --------------------- //

    function syncBalances(address[] memory _users, uint256[] memory _balances) external onlyAdmin {
        require(_users.length == _balances.length, "WooStakingManager: INVALID_INPUTS");
        uint256 len = _users.length;
        address user;
        uint256 balance;
        uint256 prevBalance;
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                user = _users[i];
                balance = _balances[i];
                prevBalance = wooBalance[user];
                if (balance > prevBalance) {
                    stakeWoo(user, balance - prevBalance);
                } else if (balance < prevBalance) {
                    unstakeWoo(user, prevBalance - balance);
                }
            }
        }
    }

    function allStakersLength() external view returns (uint256) {
        return stakers.length();
    }

    function allStakers() external view returns (address[] memory) {
        uint256 len = stakers.length();
        address[] memory _stakers = new address[](len);
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                _stakers[i] = stakers.at(i);
            }
        }
        return _stakers;
    }

    // range: [start, end)
    function allStakers(uint256 start, uint256 end) external view returns (address[] memory) {
        address[] memory _stakers = new address[](end - start);
        unchecked {
            for (uint256 i = start; i < end; ++i) {
                _stakers[i - start] = stakers.at(i);
            }
        }
        return _stakers;
    }

    // --------------------- Admin Functions --------------------- //

    function setMPRewarder(address _rewarder) external onlyAdmin {
        mpRewarder = IRewarder(_rewarder);
        require(address(IRewarder(_rewarder).stakingManager()) == address(this), "!stakingManager");

        emit SetMPRewarderOnStakingManager(_rewarder);
    }

    function addRewarder(address _rewarder) external onlyAdmin {
        require(address(IRewarder(_rewarder).stakingManager()) == address(this), "!stakingManager");
        rewarders.add(_rewarder);
        emit AddRewarderOnStakingManager(_rewarder);
    }

    function removeRewarder(address _rewarder) external onlyAdmin {
        rewarders.remove(_rewarder);
        emit RemoveRewarderOnStakingManager(_rewarder);
    }

    function setCompounder(address _compounder) external onlyAdmin {
        // remove the former compounder from `admin` if needed
        if (address(compounder) != address(0)) {
            setAdmin(address(compounder), false);
        }
        compounder = IWooStakingCompounder(_compounder);
        setAdmin(_compounder, true);
        emit SetCompounderOnStakingManager(_compounder);
    }

    function setWooPP(address _wooPP) external onlyOwner {
        wooPP = IWooPPV2(_wooPP);
        emit SetWooPPOnStakingManager(_wooPP);
    }

    function setStakingLocal(address _stakingLocal) external onlyOwner {
        // remove the former local from `admin` if needed
        if (address(stakingLocal) != address(0)) {
            setAdmin(address(stakingLocal), false);
        }
        stakingLocal = IWooStakingLocal(_stakingLocal);
        setAdmin(_stakingLocal, true);
        emit SetStakingLocalOnStakingManager(_stakingLocal);
    }
}
