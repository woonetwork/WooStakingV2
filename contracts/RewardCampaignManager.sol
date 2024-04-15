// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {RewardNFT} from "./RewardNFT.sol";

contract RewardCampaignManager is BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(uint256 => mapping(uint256 => EnumerableSet.AddressSet)) private users;
    mapping(uint256 => mapping(uint256 => EnumerableSet.AddressSet)) private claimedUsers;

    RewardNFT public rewardNFT;
    mapping(uint256 => bool) public campaignIds;

    constructor(address _rewardNFT) {
        rewardNFT = RewardNFT(_rewardNFT);
    }

    function claim(uint256 _campaignId, address _user) external onlyAdmin returns (uint128) {
        return _claim(_campaignId, _user);
    }

    function claim(uint256 _campaignId) external returns (uint128) {
        return _claim(_campaignId, msg.sender);
    }

    function _claim(uint256 _campaignId, address _user) internal returns (uint128) {
        require(campaignIds[_campaignId], "RewardCampaignManager: !campaignId");
        uint128 count = 0;
        uint256[] memory nftTypes = rewardNFT.getNftTypes();
        uint256 len = nftTypes.length;
        for (uint256 i = 0; i < len; ++i) {
            if (
                users[_campaignId][nftTypes[i]].contains(_user) &&
                !claimedUsers[_campaignId][nftTypes[i]].contains(_user)
            ) {
                rewardNFT.mint(_user, nftTypes[i], 1);
                claimedUsers[_campaignId][nftTypes[i]].add(_user);
                count++;
            }
        }
        return count;
    }

    function addUsers(uint256 _campaignId, uint256 _nftType, address[] memory _users) external onlyAdmin {
        unchecked {
            uint256 len = _users.length;
            for (uint256 i = 0; i < len; ++i) {
                _addUser(_campaignId, _nftType, _users[i]);
            }
        }
    }

    function _addUser(uint256 _campaignId, uint256 _nftType, address _user) internal {
        users[_campaignId][_nftType].add(_user);
    }

    function _removeUsers(uint256 _campaignId, uint256 _nftType, address[] memory _users) external onlyAdmin {
        unchecked {
            uint256 len = _users.length;
            for (uint256 i = 0; i < len; ++i) {
                _removeUser(_campaignId, _nftType, _users[i]);
            }
        }
    }

    function _removeUser(uint256 _campaignId, uint256 _nftType, address _user) internal returns (bool removed) {
        if (!users[_campaignId][_nftType].contains(_user)) {
            return false;
        }
        users[_campaignId][_nftType].remove(_user);
        if (claimedUsers[_campaignId][_nftType].contains(_user)) {
            claimedUsers[_campaignId][_nftType].remove(_user);
        }
        return true;
    }

    function addCampaign(uint256 _campaignId) external onlyOwner {
        campaignIds[_campaignId] = true;
    }

    function removeCampaign(uint256 _campaignId) external onlyOwner {
        campaignIds[_campaignId] = false;
    }
}
