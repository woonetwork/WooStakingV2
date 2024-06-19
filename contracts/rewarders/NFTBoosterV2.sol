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

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import {BaseAdminOperation} from "../BaseAdminOperation.sol";

import {INFTBoosterV2} from "../interfaces/INFTBoosterV2.sol";
import {IRewardNFT} from "../interfaces/IRewardNFT.sol";
import {IWooStakingManager} from "../interfaces/IWooStakingManager.sol";

contract NFTBoosterV2 is INFTBoosterV2, IERC1155Receiver, BaseAdminOperation {
    IRewardNFT public stakedNFT;
    IWooStakingManager public stakingManager;

    uint256 public base; // Default: 10000th, 100: 1%, 5000: 50%

    uint256 public tierCount = 10;

    // stakeTokenId => ttl
    mapping(uint256 => uint256) public stakeTokenTTLs;

    // Default: 10000th, 100: 1%, 5000: 50%, stakeTokenId => boostRatio
    mapping(uint256 => uint256) public boostRatios;

    // userAddress => stakeShortTokens
    mapping(address => StakeShortToken[3]) public userStakeShortTokens;
    // bucketIndex => isActive
    mapping(uint256 => bool) public isActiveBucket;
    // tier => wooBalThreshold
    mapping(uint256 => uint256) public tierThresholds;
    // tokenId => boostDecayRate
    mapping(uint256 => uint256) public tokenBoostDecayRatios;

    constructor(address _stakedNFT, address _stakingManager) {
        stakedNFT = IRewardNFT(_stakedNFT);
        stakingManager = IWooStakingManager(_stakingManager);
        base = 10000;
        isActiveBucket[0] = true;

        uint256[] memory tokenIds = stakedNFT.getAllTokenIds();
        uint256 len = tokenIds.length;
        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = tokenIds[i];
            stakeTokenTTLs[tokenId] = 5 days;
        }

        tierThresholds[1] = 1_800e18;
        tierThresholds[2] = 5_000e18;
        tierThresholds[3] = 10_000e18;
        tierThresholds[4] = 25_000e18;
        tierThresholds[5] = 100_000e18;
        tierThresholds[6] = 250_000e18;
        tierThresholds[7] = 420_000e18;
        tierThresholds[8] = 690_000e18;
        tierThresholds[9] = 1_000_000e18;
        tierThresholds[10] = 5_000_000e18;
    }

    // --------------------- Business Functions --------------------- //

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        // NOTE: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/utils/ERC1155Holder.sol
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function stakeShortNFT(uint256 _tokenId, uint256 _index) external {
        address user = msg.sender;
        require(isActiveBucket[_index], "NFTBooster: !activeBucket");
        require(_index < userStakeShortTokens[user].length, "NFTBooster: !largeBucket");
        require(stakeTokenTTLs[_tokenId] > 0, "NFTBooster: !tokenId");
        stakedNFT.safeTransferFrom(user, address(this), _tokenId, 1, "");
        userStakeShortTokens[user][_index] = StakeShortToken(_tokenId, block.timestamp);
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function boostRatio(address _user) external view returns (uint256 compoundRatio) {
        uint256 len = userStakeShortTokens[_user].length;
        uint256 userTier = getUserTier(_user);
        compoundRatio = base;
        for (uint256 i = 0; i < len; ++i) {
            if (!isActiveBucket[i]) continue; // not active bucket
            uint256 tokenId = userStakeShortTokens[_user][i].tokenId;
            uint256 timestamp = userStakeShortTokens[_user][i].timestamp;
            if (tokenId == 0) continue; // empty token
            if ((block.timestamp - timestamp) > stakeTokenTTLs[tokenId]) continue;
            uint256 ratio = boostRatios[tokenId] == 0 ? base : boostRatios[tokenId];
            uint256 accBoostDecayRatio = (base - tokenBoostDecayRatios[tokenId]) ** (userTier - 1);
            uint256 ratioAfterDecay = (ratio * accBoostDecayRatio) / (base ** (userTier - 1));
            compoundRatio = (compoundRatio * ratioAfterDecay) / base;
        }
    }

    function getUserTier(address _user) public view returns (uint256 userTier) {
        uint256 wooBal = stakingManager.wooBalance(_user);
        for (uint256 i = tierCount; i > 0; --i) {
            if (wooBal >= tierThresholds[i]) {
                return i;
            }
        }

        return 1; // regard tier0 as tier1 in nft boost calculation
    }

    // --------------------- Admin Functions --------------------- //

    function setStakedNFT(address _stakedNFT) external onlyOwner {
        stakedNFT = IRewardNFT(_stakedNFT);
    }

    function setStakingManager(address _stakingManager) external onlyOwner {
        stakingManager = IWooStakingManager(_stakingManager);
    }

    function setBase(uint256 _base) external onlyAdmin {
        base = _base;
    }

    function setTierCount(uint256 _tierCount) external onlyOwner {
        tierCount = _tierCount;
    }

    function setStakeTokenTTL(uint256 _tokenId, uint256 _ttl) external onlyAdmin {
        uint256 oldTTL = stakeTokenTTLs[_tokenId];
        stakeTokenTTLs[_tokenId] = _ttl;

        emit SetStakeTokenTTL(_tokenId, _ttl, oldTTL);
    }

    function setBoostRatios(uint256[] calldata _tokenIds, uint256[] calldata _ratios) external onlyOwner {
        uint256 len = _tokenIds.length;
        for (uint256 i = 0; i < len; ++i) {
            require(_ratios[i] != 0, "NFTBooster: !_ratios");
            boostRatios[_tokenIds[i]] = _ratios[i];
        }
    }

    function setActiveBucket(uint256 _bucket, bool _active) external onlyOwner {
        isActiveBucket[_bucket] = _active;
    }

    function setTierThresholds(uint256[] calldata _tiers, uint256[] calldata _thresholds) external onlyOwner {
        uint256 len = _tiers.length;
        for (uint256 i = 0; i < len; ++i) {
            tierThresholds[_tiers[i]] = _thresholds[i];
        }
    }

    function setTokenBoostDecayRatios(
        uint256[] calldata _tokenIds,
        uint256[] calldata _boostDecayRatios
    ) external onlyOwner {
        uint256 len = _tokenIds.length;
        for (uint256 i = 0; i < len; ++i) {
            tokenBoostDecayRatios[_tokenIds[i]] = _boostDecayRatios[i];
        }
    }
}
