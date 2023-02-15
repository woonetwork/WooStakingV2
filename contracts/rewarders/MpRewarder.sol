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

import {IRewardBooster} from "../interfaces/IRewardBooster.sol";
import {BaseRewarder} from "./BaseRewarder.sol";

contract MpRewarder is BaseRewarder {
    IRewardBooster public booster;

    constructor(address _rewardToken, address _stakingManager) BaseRewarder(_rewardToken, _stakingManager) {}

    function totalWeight() public view override returns (uint256) {
        return stakingManager.wooTotalBalance();
    }

    function weight(address _user) public view override returns (uint256) {
        // TODO: weight(user) is legic to be greater than total weight;
        // double check it works on reward claim!

        uint256 ratio = booster.boostRatio(_user);
        uint256 wooBal = stakingManager.wooBalance(_user);
        return ratio == 0 ? wooBal : (wooBal * ratio) / 1e18;
    }

    function _claim(address _user, address _to) internal override returns (uint256 rewardAmount) {
        require(address(stakingManager) == _to, "RESTRICTED_TO_STAKING_MANAGER");
        updateRewardForUser(_user);
        rewardAmount = rewardClaimable[_user];
        rewardClaimable[_user] = 0;
        totalRewardClaimable -= rewardAmount;
    }

    function setBooster(address _booster) external onlyOwner {
        booster = IRewardBooster(_booster);
    }
}
