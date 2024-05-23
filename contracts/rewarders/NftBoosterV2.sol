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

import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {RewardNFT} from "../RewardNFT.sol";

contract NftBoosterV2 is IERC1155Receiver, BaseAdminOperation {
    event SetStakeTtl(uint256 tokenId, uint256 newTtl, uint256 oldTtl);

    // only applied to controller chain
    uint256 public autoCompoundBR;

    address public stakedNft;

    uint256 public base; // Default: 10000th, 100: 1%, 5000: 50%

    // stake token id => ttl
    mapping(uint256 => uint256) public stakeTokenTtl;

    // Default: 10000th, 100: 1%, 5000: 50%, token_id => boost ratio
    mapping(uint256 => uint256) public boostRatios;

    // user_address => token_id => last stake timestamp
    mapping(address => mapping(uint256 => uint256)) public lastStakeTimestamps;
    // user_address => last stake token id => active
    mapping(address => mapping(uint256 => bool)) public isActiveStakeTokens;

    constructor(address _stakedNft) {
        base = 10000;
        stakedNft = _stakedNft;

        RewardNFT nftContract = RewardNFT(stakedNft);
        uint256[] memory nftTypes = nftContract.getNftTypes();
        uint256 len = nftTypes.length;
        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = nftTypes[i];
            if (nftContract.burnable(tokenId)) {
                stakeTokenTtl[tokenId] = 7 days;
            } else {
                stakeTokenTtl[tokenId] = 3650 days;
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

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

    function stakeNft(uint256 _tokenId) external {
        // TODO: really need to burn ERC1155 token?
        // IERC1155(stakedNft).safeTransferFrom(msg.sender, address(this), _tokenId, 1, "0x0");
        RewardNFT nftContract = RewardNFT(stakedNft);
        nftContract.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "0x0");

        lastStakeTimestamps[msg.sender][_tokenId] = block.timestamp;
        isActiveStakeTokens[msg.sender][_tokenId] = true;
    }

    function unstakeNft(uint256 _tokenId) external {
        address _user = msg.sender;
        bool isActive = isActiveStakeTokens[_user][_tokenId];
        require(isActive, "NftBooster: !tokenId");
        RewardNFT nftContract = RewardNFT(stakedNft);
        require(nftContract.burnable(_tokenId) == false, "NftBooster: burnableNft");
        nftContract.safeTransferFrom(address(this), _user, _tokenId, 1, "0x0");
        isActiveStakeTokens[_user][_tokenId] = false;
        lastStakeTimestamps[_user][_tokenId] = 0;
    }

    function boostRatio(address _user) external view returns (uint256) {
        RewardNFT nftContract = RewardNFT(stakedNft);
        uint256[] memory nftTypes = nftContract.getNftTypes();
        uint256 len = nftTypes.length;
        uint256 compoundRatio = base;
        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = nftTypes[i];
            uint256 ttl = stakeTokenTtl[tokenId];
            if (!isActiveStakeTokens[_user][tokenId]) continue;
            if ((block.timestamp - lastStakeTimestamps[_user][tokenId]) > ttl) {
                continue;
            }
            uint256 ratio = boostRatios[tokenId] == 0 ? base : boostRatios[tokenId];
            compoundRatio = (compoundRatio * ratio) / base;
        }
        return compoundRatio;
    }

    function setStakeTtl(uint256 _tokenId, uint256 _ttl) external onlyAdmin {
        uint256 oldTtl = stakeTokenTtl[_tokenId];
        stakeTokenTtl[_tokenId] = _ttl;

        emit SetStakeTtl(_tokenId, _ttl, oldTtl);
    }

    function setBase(uint256 _base) external onlyAdmin {
        base = _base;
    }

    function setBoostRatios(uint256[] calldata ids, uint256[] calldata ratios) external onlyAdmin {
        for (uint256 i = 0; i < ids.length; ++i) {
            require(ratios[i] != 0, "NftBooster: !RATIO");
            boostRatios[ids[i]] = ratios[i];
        }
    }

    function setStakedNft(address _stakedNft) external onlyAdmin {
        stakedNft = _stakedNft;
    }
}
