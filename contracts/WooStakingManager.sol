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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import "./interfaces/IRewarder.sol";
import "./interfaces/IWooStakingManager.sol";
import "./interfaces/IWooStakingProxy.sol";
import "./interfaces/IWooPPV2.sol";

import "./util/TransferHelper.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// TODO: emit events
//
contract WooStakingManager is IWooStakingManager, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    event AdminUpdated(address indexed addr, bool flag);

    uint256 public wooTotalBalance;
    mapping(address => uint256) public wooBalance;
    mapping(address => uint256) public mpBalance;

    mapping(address => bool) public isAdmin;

    IWooPPV2 public wooPP;
    IWooStakingProxy public stakingProxy;

    address public controller;
    address public immutable woo;
    address public immutable mp;

    IRewarder public mpRewarder; // Record and distribute MP rewards
    EnumerableSet.AddressSet private rewarders; // Other general rewards (e.g. usdc, eth, op, etc)

    modifier onlyAdmin() {
        require(msg.sender == owner() || isAdmin[msg.sender], "WooStakingManager: !admin");
        _;
    }

    modifier onlyController() {
        require(msg.sender == controller, "WooStakingManager: !controller");
        _;
    }

    constructor(address _controller, address _woo, address _mp, address _wooPP, address _stakingProxy) {
        controller = _controller;
        woo = _woo;
        mp = _mp;
        wooPP = IWooPPV2(_wooPP);
        stakingProxy = IWooStakingProxy(_stakingProxy);
    }

    // --------------------- Business Functions --------------------- //

    function setMPRewarder(address _rewarder) external onlyAdmin {
        mpRewarder = IRewarder(_rewarder);
        require(mpRewarder.rewardToken() == mp, "WooStakingManager: !mpRewarder");
    }

    function addRewarder(address _rewarder) external onlyAdmin {
        require(address(IRewarder(_rewarder).stakingManager()) == address(this));
        require(IRewarder(_rewarder).rewardToken() != address(mp));
        rewarders.add(_rewarder);
    }

    function removeRewarder(address _rewarder) external onlyAdmin {
        rewarders.remove(_rewarder);
    }

    function stakeWoo(address _user, uint256 _amount) public onlyController {
        mpRewarder.updateReward();

        // TODO: update other rewarders' reward

        wooBalances[_user] += _amount;
        wooTotalBalance += _amount;
    }

    function unstakeWoo(address _user, uint256 _amount) external onlyController {
        mpRewarder.updateReward();

        // TODO: update other rewarders' reward

        wooBalances[_user] -= _amount;
        wooTotalBalance -= _amount;
    }

    function stakeMP(address _user, uint256 _amount) public onlyController {
        if (msg.sender != address(this)) {
            TransferHelper.safeTransferFrom(mp, msg.sender, address(this), _amount);
        }
        mpBalances[_user] += _amount;
    }

    function unstakeMP(address _user, uint256 _amount) external onlyController {
        mpBalances[_user] -= _amount;

        // TODO: burn MP?
    }

    // 权重: have a better name
    function totalBalance(address _user) external view returns (uint256) {
        return wooBalances[_user] + mpBalances[_user];
    }

    function totalBalance() external view returns (uint256) {
        return wooTotalBalance + IERC20(mp).balanceOf(address(this));
    }

    function pendingRewards(
        address _user
    ) external returns (uint256 mpRewardAmount, address[] memory rewardTokens, uint256[] memory amounts) {
        mpRewardAmount = mpRewarder.pendingReward(_user);

        uint256 length = rewarders.length();
        rewardTokens = new address[](length);
        amounts = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            rewardTokens[i] = _rewarder.rewardToken();
            amounts[i] = _rewarder.pendingReward(_user);
        }
    }

    function claimRewards() external {
        _claim(msg.sender);
    }

    function claimRewards(address _user) external onlyController {
        _claim(_user);
    }

    function _claim(address _user) private {
        mpRewarder.claim(_user);

        for (uint256 i = 0; i < rewarders.length(); ++i) {
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            _rewarder.claim(_user);
        }
    }

    function compoundAll(address _user) external onlyController {
        compoundMP(_user);
        compoundRewards(_user);
    }

    function compoundMP(address _user) public onlyController {
        // For MP, claim and then directly stake.
        uint256 amount = mpRewarder.claim(_user, address(this));

        // NO need to transfer MP token to self again
        mpBalances[_user] += amount;
    }

    function compoundRewards(address _user) public onlyController {
        // For other general rewards, claim and then swap to compound token, and then stake.
        uint256 wooAmount = 0;
        address selfAddr = address(this);
        for (uint256 i = 0; i < rewarders.length(); ++i) {
            IRewarder _rewarder = IRewarder(rewarders.at(i));
            uint256 amount = _rewarder.claim(_user, selfAddr);

            // NOTE: a more general approach
            // TransferHelper.safeApprove(_rewarder.rewardToken(), address(_rewarder), amount);
            // uint256 compoundAmount = _rewarder.swapToCompoundToken(address(this));
            // stakeToken(_rewarder.compoundToken(), _user, compoundAmount);
            TransferHelper.safeApprove(_rewarder.rewardToken(), address(wooPP), amount);
            if (_rewarder.rewardToken() != woo) {
                wooAmount += wooPP.swap(_rewarder.rewardToken(), woo, amount, 0, selfAddr, selfAddr);
            }
        }

        TransferHelper.safeApprove(woo, address(stakingProxy), wooAmount);
        stakingProxy.stake(_user, wooAmount);
    }

    // --------------------- Admin Functions --------------------- //

    function pause() public onlyAdmin {
        super._pause();
    }

    function unpause() public onlyAdmin {
        super._unpause();
    }

    function setAdmin(address addr, bool flag) external onlyAdmin {
        isAdmin[addr] = flag;
        emit AdminUpdated(addr, flag);
    }

    function setWooPP(address _wooPP) external onlyAdmin {
        wooPP = IWooPPV2(_wooPP);
    }

    function inCaseTokenGotStuck(address stuckToken) external onlyOwner {
        if (stuckToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        } else {
            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }
}
