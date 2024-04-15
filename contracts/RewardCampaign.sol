// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {RewardNFT} from "./RewardNFT.sol";

contract RewardCampaign is BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(uint256 => EnumerableSet.AddressSet) private users;
    mapping(uint256 => EnumerableSet.AddressSet) private claimedUsers;

    RewardNFT public rewardNFT;

    constructor(address _rewardNFT) {
        rewardNFT = RewardNFT(_rewardNFT);
    }

    function claim(address _user) external onlyAdmin returns (uint128) {
        return _claim(_user);
    }

    function claim() external returns (uint128) {
        return _claim(msg.sender);
    }

    function _claim(address _user) internal returns (uint128) {
        uint128 count = 0;
        uint256[] memory nftTypes = rewardNFT.getNftTypes();
        uint256 len = nftTypes.length;
        for (uint256 i = 0; i < len; ++i) {
            if (users[nftTypes[i]].contains(_user) && !claimedUsers[nftTypes[i]].contains(_user)) {
                rewardNFT.mint(_user, nftTypes[i], 1);
                claimedUsers[nftTypes[i]].add(_user);
                count++;
            }
        }
        return count;
    }

    function addUsers(uint256 _nftType, address[] memory _users) external onlyAdmin {
        unchecked {
            uint256 len = _users.length;
            for (uint256 i = 0; i < len; ++i) {
                _addUser(_nftType, _users[i]);
            }
        }
    }

    function _addUser(uint256 _nftType, address _user) internal {
        users[_nftType].add(_user);
    }

    function _removeUsers(uint256 _nftType, address[] memory _users) external onlyAdmin {
        unchecked {
            uint256 len = _users.length;
            for (uint256 i = 0; i < len; ++i) {
                _removeUser(_nftType, _users[i]);
            }
        }
    }

    function _removeUser(uint256 _nftType, address _user) internal returns (bool removed) {
        if (!users[_nftType].contains(_user)) {
            return false;
        }
        users[_nftType].remove(_user);
        if (claimedUsers[_nftType].contains(_user)) {
            claimedUsers[_nftType].remove(_user);
        }
        return true;
    }
}
