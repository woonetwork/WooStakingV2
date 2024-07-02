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
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {BaseAdminOperation} from "./BaseAdminOperation.sol";

import {IRewardNFT} from "./interfaces/IRewardNFT.sol";

interface IERC2981Royalties {
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _value
    ) external view returns (address _receiver, uint256 _royaltyAmount);
}

/// @dev This is a contract used to add ERC2981 support to ERC721 and 1155
abstract contract ERC2981Base is ERC165, IERC2981Royalties {
    struct RoyaltyInfo {
        address recipient;
        uint24 amount;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IERC2981Royalties).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract RewardNFT is IRewardNFT, ERC1155, BaseAdminOperation, ERC2981Base {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    uint256 public constant UNCOMMON = 1;
    uint256 public constant RARE = 2;
    uint256 public constant EPIC = 3;

    address public campaignManager;
    address public nftBooster;

    uint256[] public tokenIds;
    mapping(uint256 => bool) public burnables;

    mapping(uint256 => string) private baseURIs;

    RoyaltyInfo private _royalties;
    string public name;
    string public symbol;

    constructor(string memory _name, string memory _symbol) ERC1155("") {
        name = _name;
        symbol = _symbol;
        _addTokenId(UNCOMMON, true);
        _addTokenId(RARE, true);
        _addTokenId(EPIC, true);
    }

    // --------------------- Business Functions --------------------- //

    function royaltyInfo(
        uint256,
        uint256 value
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        RoyaltyInfo memory royalties = _royalties;
        receiver = royalties.recipient;
        royaltyAmount = (value * royalties.amount) / 10000;
    }

    function mint(address _user, uint256 _tokenId, uint256 _amount) external {
        require(msg.sender == campaignManager, "RewardNFT: !campaignManager");
        _mint(_user, _tokenId, _amount, "");
    }

    function burn(address _user, uint256 _tokenId, uint256 _amount) external {
        require(msg.sender == nftBooster, "RewardNFT: !nftBooster");
        _burn(_user, _tokenId, _amount);
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

    function setNFTBooster(address _nftBooster) external onlyOwner {
        nftBooster = _nftBooster;
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

    function setSymbol(string memory _symbol) external onlyAdmin {
        symbol = _symbol;
    }

    function setName(string memory _name) external onlyAdmin {
        name = _name;
    }

    function setRoyalties(address recipient, uint256 amount) external onlyAdmin {
        // Amount is in basis points so 10000 = 100% , 100 = 1% etc
        require(amount <= 10000, "RewardNFT: RoyaltyTooHigh");
        _royalties = RoyaltyInfo(recipient, uint24(amount));
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC2981Base, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
