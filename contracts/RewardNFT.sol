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

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {BaseAdminOperation} from "./BaseAdminOperation.sol";

import {IRewardNFT} from "./interfaces/IRewardNFT.sol";

contract RewardNFT is IRewardNFT, ERC1155, BaseAdminOperation {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    uint256 public constant UNCOMMON = 1;
    uint256 public constant RARE = 2;
    uint256 public constant EPIC = 3;

    address public campaignManager;

    uint256[] public tokenIds;
    mapping(uint256 => bool) public burnables;

    mapping(uint256 => string) private baseURIs;

    constructor() ERC1155("") {
        _addTokenId(UNCOMMON, true);
        _addTokenId(RARE, true);
        _addTokenId(EPIC, true);
    }

    // --------------------- Business Functions --------------------- //

    function mint(address _user, uint256 _tokenId, uint256 _amount) external {
        require(msg.sender == campaignManager, "RewardNFT: !campaignManager");
        _mint(_user, _tokenId, _amount, "");
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return tokenIds;
    }

    function uri(uint256 _tokenId) public view override returns (string memory) {
        uint256 len = tokenIds.length;
        for (uint256 i = 0; i < len; i += 1) {
            if (_tokenId == tokenIds[i]) {
                return string(abi.encodePacked(baseURIs[_tokenId], _tokenId.toString()));
            }
        }

        return "";
    }

    function _addTokenId(uint256 _tokenId, bool _burnable) internal {
        bool exist = false;
        uint256 len = tokenIds.length;
        for (uint256 i = 0; i < len; i++) {
            if (tokenIds[i] == _tokenId) {
                exist = true;
                break;
            }
        }
        require(exist == false, "RewardNFT: !_tokenId");
        tokenIds.push(_tokenId);
        burnables[_tokenId] = _burnable;
    }

    // --------------------- Admin Functions --------------------- //

    function batchAirdrop(address[] memory _users, uint256 _tokenId, uint256 _amount) external onlyAdmin {
        uint256 len = _users.length;
        for (uint256 i = 0; i < len; ++i) {
            _mint(_users[i], _tokenId, _amount, "");
        }
    }

    function setCampaignManager(address _campaignManager) external onlyOwner {
        campaignManager = _campaignManager;
    }

    function addTokenId(uint256 _tokenId, bool _burnable) external onlyOwner {
        _addTokenId(_tokenId, _burnable);
    }

    function setBurnable(uint256 _tokenId, bool _burnable) external onlyOwner {
        burnables[_tokenId] = _burnable;
    }

    function setBaseURI(uint256 _tokenId, string memory _baseURI) external onlyAdmin {
        baseURIs[_tokenId] = _baseURI;

        emit URI(string(abi.encodePacked(_baseURI, _tokenId.toString())), _tokenId);
    }
}
