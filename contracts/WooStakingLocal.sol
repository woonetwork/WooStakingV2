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

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWooStakingLocal} from "./interfaces/IWooStakingLocal.sol";
import {IWooStakingManager} from "./interfaces/IWooStakingManager.sol";
import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {TransferHelper} from "./util/TransferHelper.sol";

contract WooStakingLocal is IWooStakingLocal, BaseAdminOperation, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bool public isEmergency;
    IWooStakingManager public stakingManager;
    IERC20 public immutable want;

    mapping(address => uint256) public balances;

    constructor(address _want, address _stakingManager) {
        require(_want != address(0), "WooStakingLocal: !_want");
        require(_stakingManager != address(0), "WooStakingLocal: !_stakingManager");

        want = IERC20(_want);
        stakingManager = IWooStakingManager(_stakingManager);
        isEmergency = false;
    }

    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        _stake(msg.sender, _amount);
    }

    // CAUTION: nonReentrant cannot be placed here:
    // https://dashboard.tenderly.co/tx/fantom/0x80cf10fd96e3cce75391c2067e25dd73b0fe27621088d8fa111f24b57d3d1341
    function stake(address _user, uint256 _amount) external whenNotPaused onlyAdmin {
        _stake(_user, _amount);
    }

    function _stake(address _user, uint256 _amount) internal {
        want.safeTransferFrom(msg.sender, address(this), _amount);
        balances[_user] += _amount;
        emit StakeOnLocal(_user, _amount);
        stakingManager.stakeWoo(_user, _amount);
    }

    function unstake(uint256 _amount) external nonReentrant {
        _unstake(msg.sender, _amount);
    }

    function unstakeAll() external nonReentrant {
        _unstake(msg.sender, balances[msg.sender]);
    }

    function emergencyUnstake() external {
        require(isEmergency, "WooStakingLocal: !allow");
        uint256 _amount = balances[msg.sender];
        balances[msg.sender] -= _amount;
        want.safeTransfer(msg.sender, _amount);
        emit UnstakeOnLocal(msg.sender, _amount);
    }

    function _unstake(address _user, uint256 _amount) internal {
        require(balances[_user] >= _amount, "WooStakingLocal: !BALANCE");
        balances[_user] -= _amount;
        want.safeTransfer(_user, _amount);
        emit UnstakeOnLocal(_user, _amount);
        stakingManager.unstakeWoo(_user, _amount);
    }

    function setAutoCompound(bool _flag) external whenNotPaused nonReentrant {
        address _user = msg.sender;
        stakingManager.setAutoCompound(_user, _flag);
        emit SetAutoCompoundOnLocal(_user, _flag);
    }

    function compoundMP() external whenNotPaused nonReentrant {
        address _user = msg.sender;
        stakingManager.compoundMP(_user);
        emit CompoundMPOnLocal(_user);
    }

    function compoundAll() external whenNotPaused nonReentrant {
        address _user = msg.sender;
        stakingManager.compoundAll(_user);
        emit CompoundAllOnLocal(_user);
    }

    // --------------------- Admin Functions --------------------- //

    function setStakingManager(address _stakingManager) external onlyAdmin {
        stakingManager = IWooStakingManager(_stakingManager);
        // NOTE: don't forget to set stakingLocal as the admin of stakingManager
        emit SetStakingManagerOnLocal(_stakingManager);
    }

    function setIsEmergency(bool _isEmergency) external onlyOwner {
        isEmergency = _isEmergency;
    }

    function inCaseTokenGotStuck(address stuckToken) external override onlyOwner {
        require(stuckToken != address(want), "WooStakingLocal: !want");
        if (stuckToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            TransferHelper.safeTransferETH(_msgSender(), address(this).balance);
        } else {
            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, _msgSender(), amount);
        }
    }
}
