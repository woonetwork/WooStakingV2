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

import {BaseAdminOperation} from "./BaseAdminOperation.sol";

import {IRewardCampaignManager} from "./interfaces/IRewardCampaignManager.sol";
import {IRewardNFT} from "./interfaces/IRewardNFT.sol";

contract RewardCampaignManager is IRewardCampaignManager, BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;

    IRewardNFT public rewardNFT;

    // campaignId -> tokenId -> userList
    mapping(uint256 => mapping(uint256 => EnumerableSet.AddressSet)) private users;

    // campaignId -> tokenId -> userAddress -> isClaimed
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private isClaimedUser;

    // campaignId -> isActive
    mapping(uint256 => bool) public isActiveCampaign;

    constructor(address _rewardNFT) {
        rewardNFT = IRewardNFT(_rewardNFT);
    }

    // --------------------- Business Functions --------------------- //

    function claim(uint256 _campaignId) external returns (uint128) {
        return _claim(_campaignId, msg.sender);
    }

    function isClaimed(uint256 _campaignId, uint256 _tokenId, address _user) external view returns (bool) {
        return isClaimedUser[_campaignId][_tokenId][_user];
    }

    function _claim(uint256 _campaignId, address _user) internal returns (uint128) {
        require(isActiveCampaign[_campaignId], "RewardCampaignManager: !_campaignId");
        uint128 count = 0;
        uint256[] memory tokenIds = rewardNFT.getAllTokenIds();
        uint256 len = tokenIds.length;
        for (uint256 i = 0; i < len; ++i) {
            if (users[_campaignId][tokenIds[i]].contains(_user) && !isClaimedUser[_campaignId][tokenIds[i]][_user]) {
                rewardNFT.mint(_user, tokenIds[i], 1);
                isClaimedUser[_campaignId][tokenIds[i]][_user] = true;
                count++;
            }
        }
        return count;
    }

    function _addUser(uint256 _campaignId, uint256 _tokenId, address _user) internal {
        users[_campaignId][_tokenId].add(_user);
    }

    function _removeUser(uint256 _campaignId, uint256 _tokenId, address _user) internal returns (bool removed) {
        if (!users[_campaignId][_tokenId].contains(_user)) {
            return false;
        }
        users[_campaignId][_tokenId].remove(_user);
        if (isClaimedUser[_campaignId][_tokenId][_user]) {
            isClaimedUser[_campaignId][_tokenId][_user] = false;
        }
        return true;
    }

    // --------------------- Admin Functions --------------------- //

    function claim(uint256 _campaignId, address _user) external onlyAdmin returns (uint128) {
        return _claim(_campaignId, _user);
    }

    function addUsers(uint256 _campaignId, uint256 _tokenId, address[] memory _users) external onlyAdmin {
        uint256 len = _users.length;
        for (uint256 i = 0; i < len; ++i) {
            _addUser(_campaignId, _tokenId, _users[i]);
        }
    }

    function removeUsers(uint256 _campaignId, uint256 _tokenId, address[] memory _users) external onlyAdmin {
        uint256 len = _users.length;
        for (uint256 i = 0; i < len; ++i) {
            _removeUser(_campaignId, _tokenId, _users[i]);
        }
    }

    function setRewardNFT(address _rewardNFT) external onlyOwner {
        rewardNFT = IRewardNFT(_rewardNFT);
    }

    function addCampaign(uint256 _campaignId) external onlyOwner {
        isActiveCampaign[_campaignId] = true;
    }

    function removeCampaign(uint256 _campaignId) external onlyOwner {
        isActiveCampaign[_campaignId] = false;
    }
}
