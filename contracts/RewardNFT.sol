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
    uint256[] public nftTypes;
    mapping(uint256 => bool) burnableNFT;
    address public campaignManager;

    string private initUri = "https://oss.woo.org/static/images/nft/{id}.gif";

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

    function getNftTypes() external view returns (uint256[] memory) {
        return nftTypes;
    }

    function mint(address _user, uint256 _nftType, uint256 _amount) external {
        require(msg.sender == campaignManager, "RewardNFT: !campaignManager");
        _mint(_user, _nftType, _amount, "");
    }

    function mintByAdmin(address _user, uint256 _nftType, uint256 _amount) external onlyAdmin {
        _mint(_user, _nftType, _amount, "");
    }

    function setUri(string memory uri) external onlyAdmin {
        _setURI(uri);
    }

    function addNFTType(uint256 _nftType, bool _burnable) external onlyOwner {
        _addNFTType(_nftType, _burnable);
    }

    function setBurnable(uint256 _nftType, bool _burnable) external onlyOwner {
        burnableNFT[_nftType] = _burnable;
    }

    function setCampaignManager(address _campaignManager) external onlyOwner {
        campaignManager = _campaignManager;
    }
}
