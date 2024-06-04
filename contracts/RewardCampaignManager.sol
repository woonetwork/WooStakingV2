// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {RewardNFT} from "./RewardNFT.sol";

contract RewardCampaignManager is BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;

    // campaign_id -> nft_type -> user_list
    mapping(uint256 => mapping(uint256 => EnumerableSet.AddressSet)) private users;

    // campaign_id -> nft_type -> user -> claimed
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private isClaimedUser;

    RewardNFT public rewardNFT;
    mapping(uint256 => bool) public isActiveCampaign;

    constructor(address _rewardNFT) {
        rewardNFT = RewardNFT(_rewardNFT);
    }

    function claim(uint256 _campaignId, address _user) external onlyAdmin returns (uint128) {
        return _claim(_campaignId, _user);
    }

    function claim(uint256 _campaignId) external returns (uint128) {
        return _claim(_campaignId, msg.sender);
    }

    function isClaimed(uint256 _campaignId, uint256 _nftType, address _user) external view returns (bool) {
        return isClaimedUser[_campaignId][_nftType][_user];
    }

    function _claim(uint256 _campaignId, address _user) internal returns (uint128) {
        require(isActiveCampaign[_campaignId], "RewardCampaignManager: !campaignId");
        uint128 count = 0;
        uint256[] memory nftTypes = rewardNFT.getNftTypes();
        uint256 len = nftTypes.length;
        for (uint256 i = 0; i < len; ++i) {
            if (users[_campaignId][nftTypes[i]].contains(_user) && !isClaimedUser[_campaignId][nftTypes[i]][_user]) {
                rewardNFT.mint(_user, nftTypes[i], 1);
                isClaimedUser[_campaignId][nftTypes[i]][_user] = true;
                count++;
            }
        }
        return count;
    }

    function addUsers(uint256 _campaignId, uint256 _nftType, address[] memory _users) external onlyAdmin {
        uint256 len = _users.length;
        for (uint256 i = 0; i < len; ++i) {
            _addUser(_campaignId, _nftType, _users[i]);
        }
    }

    function _addUser(uint256 _campaignId, uint256 _nftType, address _user) internal {
        users[_campaignId][_nftType].add(_user);
    }

    function removeUsers(uint256 _campaignId, uint256 _nftType, address[] memory _users) external onlyAdmin {
        uint256 len = _users.length;
        for (uint256 i = 0; i < len; ++i) {
            _removeUser(_campaignId, _nftType, _users[i]);
        }
    }

    function _removeUser(uint256 _campaignId, uint256 _nftType, address _user) internal returns (bool removed) {
        if (!users[_campaignId][_nftType].contains(_user)) {
            return false;
        }
        users[_campaignId][_nftType].remove(_user);
        if (isClaimedUser[_campaignId][_nftType][_user]) {
            isClaimedUser[_campaignId][_nftType][_user] = false;
        }
        return true;
    }

    function addCampaign(uint256 _campaignId) external onlyOwner {
        isActiveCampaign[_campaignId] = true;
    }

    function removeCampaign(uint256 _campaignId) external onlyOwner {
        isActiveCampaign[_campaignId] = false;
    }

    function setRewardNFT(address _rewardNFT) external onlyOwner {
        rewardNFT = RewardNFT(_rewardNFT);
    }
}
