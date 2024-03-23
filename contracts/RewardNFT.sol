// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract RewardNFT is ERC1155, BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant EPIC = 0;
    uint256 public constant RARE = 1;
    uint256 public constant COMMON = 2;

    mapping(uint256 => mapping(uint256 => EnumerableSet.AddressSet)) private nftUsers;
    mapping(uint256 => mapping(uint256 => EnumerableSet.AddressSet)) private claimedUsers;
    uint256[] public nftTypes;
    mapping(uint256 => bool) burnableNFT;
    uint256 currentCampaign;

    string private initUri = "https://game.example/api/item/{id}.json";

    constructor() public ERC1155(initUri) {
        _addNFTType(EPIC, false);
        _addNFTType(RARE, false);
        _addNFTType(COMMON, false);
    }

    function _addNFTType(uint256 _nftType, bool _burnable) internal {
        nftTypes.push(_nftType);
        burnableNFT[_nftType] = _burnable;
    }

    function burnable(uint256 _nftType) external view returns (bool) {
        return burnableNFT[_nftType];
    }

    function claim(address _user) external onlyAdmin returns (uint128) {
        return _claim(_user);
    }

    function claim() external returns (uint128) {
        return _claim(msg.sender);
    }

    function _claim(address _user) internal returns (uint128) {
        uint128 count = 0;
        uint256 len = nftTypes.length;
        for (uint256 i = 0; i < len; ++i) {
            if (
                nftUsers[currentCampaign][nftTypes[i]].contains(_user) &&
                !claimedUsers[currentCampaign][nftTypes[i]].contains(_user)
            ) {
                _mint(_user, nftTypes[i], 1, "");
                claimedUsers[currentCampaign][nftTypes[i]].add(_user);
                count++;
            }
        }
        return count;
    }

    // function safeTransfer(uint256 _nftType, address _user, uint256 _amount) external onlyAdmin {
    //     _safeTransferFrom(address(this), _user, _nftType, _amount, "0x0");
    // }

    function addUsers(uint256 _nftType, address[] memory _users) external onlyAdmin {
        unchecked {
            uint256 len = _users.length;
            for (uint256 i = 0; i < len; ++i) {
                _addUser(_nftType, _users[i]);
            }
        }
    }

    function _addUser(uint256 _nftType, address _user) internal {
        nftUsers[currentCampaign][_nftType].add(_user);
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
        if (!nftUsers[currentCampaign][_nftType].contains(_user)) {
            return false;
        }
        nftUsers[currentCampaign][_nftType].remove(_user);
        if (claimedUsers[currentCampaign][_nftType].contains(_user)) {
            claimedUsers[currentCampaign][_nftType].remove(_user);
        }
        return true;
    }

    function setUri(string memory uri) external onlyAdmin {
        _setURI(uri);
    }

    function setCampaign(uint256 _campaign) external onlyAdmin {
        currentCampaign = _campaign;
    }

    function addNFTType(uint256 _nftType, bool _burnable) external onlyOwner {
        _addNFTType(_nftType, _burnable);
    }

    function setBurnable(uint256 _nftType, bool _burnable) external onlyOwner {
        burnableNFT[_nftType] = _burnable;
    }
}
