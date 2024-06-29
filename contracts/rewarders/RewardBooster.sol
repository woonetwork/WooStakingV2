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
import {INFTBoosterV2} from "../interfaces/INFTBoosterV2.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";
import {IWooStakingCompounder} from "../interfaces/IWooStakingCompounder.sol";

contract RewardBooster is IRewardBooster, BaseAdminOperation {
    // BR = Boost Ratio,
    // In unit 10000th: 100: 1%, 5000: 50%
    uint256 public volumeBR;
    uint256 public tvlBR;

    // only applied to controller chain
    uint256 public autoCompoundBR;

    uint256 public mpWooBR1;
    uint256 public mpWooBR2;

    mapping(address => uint256) public boostRatio;

    struct UserBoostRatioDetail {
        uint256 volRatio;
        uint256 tvlRatio;
        uint256 autoCompoundRatio;
        uint256 nftRatio;
        uint256 mpWooRatio;
        uint256 userTier;
        uint256[3] stakeTokenIds;
    }
    mapping(address => UserBoostRatioDetail) public userBoostRatioDetail;

    uint256 public immutable base; // Default: 10000th, 100: 1%, 5000: 50%

    IRewarder public mpRewarder;

    IWooStakingCompounder public compounder;

    INFTBoosterV2 public nftBooster;

    constructor(address _mpRewarder, address _compounder, address _nftBooster) {
        base = 10000;
        volumeBR = 13000; // 130%
        tvlBR = 13000; // 130%
        autoCompoundBR = 15000; // 150%
        mpWooBR1 = 5000; // 50%
        mpWooBR2 = 0; // 0%
        mpRewarder = IRewarder(_mpRewarder);
        compounder = IWooStakingCompounder(_compounder);
        nftBooster = INFTBoosterV2(_nftBooster);
    }

    function setUserRatios(
        address[] memory users,
        bool[] memory volFlags,
        bool[] memory tvlFlags,
        uint256[] memory mpWooRatios
    ) external onlyAdmin {
        uint256 ratio;
        UserBoostRatioDetail memory ratioDetail;
        unchecked {
            for (uint256 i = 0; i < users.length; ++i) {
                address _user = users[i];
                mpRewarder.updateRewardForUser(_user); // settle the reward for prevous boost ratios
                (ratio, ratioDetail) = _calculate_ratio(_user, volFlags[i], tvlFlags[i], mpWooRatios[i]);
                userBoostRatioDetail[_user] = ratioDetail;
                boostRatio[_user] = ratio;
                mpRewarder.clearRewardToDebt(_user);
            }
        }
    }

    function migrateUserRatios(
        address[] memory users,
        bool[] memory volFlags,
        bool[] memory tvlFlags,
        uint256[] memory mpWooRatios
    ) external onlyAdmin {
        uint256 ratio;
        UserBoostRatioDetail memory ratioDetail;
        unchecked {
            for (uint256 i = 0; i < users.length; ++i) {
                address _user = users[i];
                (ratio, ratioDetail) = _calculate_ratio(_user, volFlags[i], tvlFlags[i], mpWooRatios[i]);
                userBoostRatioDetail[_user] = ratioDetail;
                boostRatio[_user] = ratio;
            }
        }
    }

    function _calculate_ratio(
        address _user,
        bool _volFlag,
        bool _tvlFlag,
        uint256 mpWooRatio
    ) internal returns (uint256 ratio, UserBoostRatioDetail memory ratioDetail) {
        uint256 nftRatio;
        uint256[3] memory stakeTokenIds;
        (nftRatio, stakeTokenIds) = nftBooster.boostRatio(_user);
        UserBoostRatioDetail memory item = UserBoostRatioDetail({
            volRatio: _volFlag ? volumeBR : base,
            tvlRatio: _tvlFlag ? tvlBR : base,
            autoCompoundRatio: compounder.contains(_user) ? autoCompoundBR : base,
            nftRatio: nftRatio,
            mpWooRatio: mpWooRatio,
            userTier: nftBooster.getUserTier(_user),
            stakeTokenIds: stakeTokenIds
        });
        ratio =
            (item.volRatio * item.tvlRatio * item.nftRatio * item.autoCompoundRatio) /
            base /
            base /
            nftBooster.base();
        if (item.mpWooRatio >= 10000) {
            ratio = (ratio * mpWooBR1) / base;
        }
        if (item.mpWooRatio >= 5000 && !_volFlag && !_tvlFlag && !compounder.contains(_user)) {
            ratio = (ratio * mpWooBR2) / base;
        }
        ratioDetail = item;
    }

    function setMPRewarder(address _rewarder) external onlyAdmin {
        mpRewarder = IRewarder(_rewarder);
        emit SetMPRewarder(_rewarder);
    }

    function setAutoCompounder(address _compounder) external onlyAdmin {
        compounder = IWooStakingCompounder(_compounder);
        emit SetAutoCompounder(_compounder);
    }

    function setNFTBooster(address _nftBooster) external onlyAdmin {
        nftBooster = INFTBoosterV2(_nftBooster);
        emit SetNFTBooster(_nftBooster);
    }

    function setVolumeBR(uint256 _br) external onlyAdmin {
        volumeBR = _br;
        emit SetVolumeBR(_br);
    }

    function setTvlBR(uint256 _br) external onlyAdmin {
        tvlBR = _br;
        emit SetTvlBR(_br);
    }

    function setMPWooBR(uint256 _br1, uint256 _br2) external onlyAdmin {
        mpWooBR1 = _br1;
        mpWooBR2 = _br2;
    }

    function setAutoCompoundBR(uint256 _br) external onlyAdmin {
        autoCompoundBR = _br;
        emit SetAutoCompoundBR(_br);
    }
}
