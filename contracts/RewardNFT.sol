// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {BaseAdminOperation} from "./BaseAdminOperation.sol";

contract RewardNFT is ERC1155, BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant UNCOMMON = 1;
    uint256 public constant RARE = 2;
    uint256 public constant EPIC = 3;

    uint256[] public nftTypes;
    mapping(uint256 => bool) public burnables;

    address public campaignManager;

    string private initUri = "https://oss.woo.org/static/images/nft/{id}.webm";

    constructor() ERC1155(initUri) {
        _addNFTType(UNCOMMON, true);
        _addNFTType(RARE, true);
        _addNFTType(EPIC, true);
    }

    // --------------------- Business Functions --------------------- //

    function mint(address _user, uint256 _nftType, uint256 _amount) external {
        require(msg.sender == campaignManager, "RewardNFT: !campaignManager");
        _mint(_user, _nftType, _amount, "");
    }

    function getAllNFTTypes() external view returns (uint256[] memory) {
        return nftTypes;
    }

    function _addNFTType(uint256 _nftType, bool _burnable) internal {
        bool exist = false;
        for (uint256 i = 0; i < nftTypes.length; i++) {
            if (nftTypes[i] == _nftType) {
                exist = true;
                break;
            }
        }
        require(exist == false, "RewardNFT: !_nftType");
        nftTypes.push(_nftType);
        burnables[_nftType] = _burnable;
    }

    // --------------------- Admin Functions --------------------- //

    function batchAirdrop(address[] memory _users, uint256 _nftType, uint256 _amount) external onlyAdmin {
        uint256 len = _users.length;
        for (uint256 i = 0; i < len; ++i) {
            _mint(_users[i], _nftType, _amount, "");
        }
    }

    function setUri(string memory uri) external onlyAdmin {
        _setURI(uri);
    }

    function addNFTType(uint256 _nftType, bool _burnable) external onlyOwner {
        _addNFTType(_nftType, _burnable);
    }

    function setBurnable(uint256 _nftType, bool _burnable) external onlyOwner {
        burnables[_nftType] = _burnable;
    }

    function setCampaignManager(address _campaignManager) external onlyOwner {
        campaignManager = _campaignManager;
    }
}
