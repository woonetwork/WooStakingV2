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

import {IRewarder} from "../interfaces/IRewarder.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";
import {IWooStakingCompounder} from "../interfaces/IWooStakingCompounder.sol";

import {NftBooster} from "./NftBooster.sol";

contract RewardBooster is IRewardBooster, BaseAdminOperation {
    // BR = Boost Ratio,
    // In unit 10000th: 100: 1%, 5000: 50%
    uint256 public volumeBR;
    uint256 public tvlBR;

    // only applied to controller chain
    uint256 public autoCompoundBR;

    mapping(address => uint256) public boostRatio;

    uint256 public immutable base; // Default: 10000th, 100: 1%, 5000: 50%

    IRewarder public mpRewarder;

    IWooStakingCompounder public compounder;

    NftBooster public nftBooster;

    constructor(address _mpRewarder, address _compounder, address _nftBooster) {
        base = 10000;
        volumeBR = 13000; // 130%
        tvlBR = 13000; // 130%
        autoCompoundBR = 15000; // 150%
        mpRewarder = IRewarder(_mpRewarder);
        compounder = IWooStakingCompounder(_compounder);
        nftBooster = NftBooster(_nftBooster);
    }

    function setUserRatios(address[] memory users, bool[] memory volFlags, bool[] memory tvlFlags) external onlyAdmin {
        unchecked {
            for (uint256 i = 0; i < users.length; ++i) {
                address _user = users[i];
                mpRewarder.updateRewardForUser(_user); // settle the reward for prevous boost ratios
                boostRatio[_user] =
                    ((volFlags[i] ? volumeBR : base) *
                        (tvlFlags[i] ? tvlBR : base) *
                        nftBooster.boostRatio(_user) *
                        (compounder.contains(_user) ? autoCompoundBR : base)) /
                    base /
                    base /
                    nftBooster.base();
                mpRewarder.clearRewardToDebt(_user);
            }
        }
    }

    function setMPRewarder(address _rewarder) external onlyAdmin {
        mpRewarder = IRewarder(_rewarder);
        emit SetMPRewarder(_rewarder);
    }

    function setAutoCompounder(address _compounder) external onlyAdmin {
        compounder = IWooStakingCompounder(_compounder);
        emit SetAutoCompounder(_compounder);
    }

    function setNftBooster(address _nftBooster) external onlyAdmin {
        nftBooster = NftBooster(_nftBooster);
        emit SetNftBooster(_nftBooster);
    }

    function setVolumeBR(uint256 _br) external onlyAdmin {
        volumeBR = _br;
        emit SetVolumeBR(_br);
    }

    function setTvlBR(uint256 _br) external onlyAdmin {
        tvlBR = _br;
        emit SetTvlBR(_br);
    }

    function setAutoCompoundBR(uint256 _br) external onlyAdmin {
        autoCompoundBR = _br;
        emit SetAutoCompoundBR(_br);
    }
}
