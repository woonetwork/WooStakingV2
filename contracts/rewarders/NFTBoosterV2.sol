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

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import {BaseAdminOperation} from "../BaseAdminOperation.sol";

import {INFTBoosterV2} from "../interfaces/INFTBoosterV2.sol";
import {IRewardNFT} from "../interfaces/IRewardNFT.sol";

contract NFTBoosterV2 is INFTBoosterV2, IERC1155Receiver, BaseAdminOperation {
    IRewardNFT public stakedNFT;

    uint256 public base; // Default: 10000th, 100: 1%, 5000: 50%

    // stakeTokenId => ttl
    mapping(uint256 => uint256) public stakeTokenTTLs;

    // Default: 10000th, 100: 1%, 5000: 50%, stakeTokenId => boostRatio
    mapping(uint256 => uint256) public boostRatios;

    // userAddress => stakeShortTokens
    mapping(address => StakeShortToken[3]) public userStakeShortTokens;
    mapping(uint256 => bool) public isActiveBucket;

    constructor(address _stakedNFT) {
        stakedNFT = IRewardNFT(_stakedNFT);
        base = 10000;
        isActiveBucket[0] = true;

        uint256[] memory tokenIds = stakedNFT.getAllTokenIds();
        uint256 len = tokenIds.length;
        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = tokenIds[i];
            stakeTokenTTLs[tokenId] = 5 days;
        }
    }

    // --------------------- Business Functions --------------------- //

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

    function stakeShortNFT(uint256 _tokenId, uint256 _index) external {
        address user = msg.sender;
        require(isActiveBucket[_index], "NFTBooster: !activeBucket");
        require(_index < userStakeShortTokens[user].length, "NFTBooster: !largeBucket");
        require(stakeTokenTTLs[_tokenId] > 0, "NFTBooster: !tokenId");
        stakedNFT.safeTransferFrom(user, address(this), _tokenId, 1, "");
        userStakeShortTokens[user][_index] = StakeShortToken(_tokenId, block.timestamp);
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function boostRatio(address _user) external view returns (uint256 compoundRatio) {
        uint256 len = userStakeShortTokens[_user].length;
        compoundRatio = base;
        for (uint256 i = 0; i < len; ++i) {
            if (!isActiveBucket[i]) continue; // not active bucket
            uint256 tokenId = userStakeShortTokens[_user][i].tokenId;
            uint256 timestamp = userStakeShortTokens[_user][i].timestamp;
            if (tokenId == 0) continue; // empty token
            if ((block.timestamp - timestamp) > stakeTokenTTLs[tokenId]) continue;
            uint256 ratio = boostRatios[tokenId] == 0 ? base : boostRatios[tokenId];
            compoundRatio = (compoundRatio * ratio) / base;
        }
    }

    // --------------------- Admin Functions --------------------- //

    function setStakedNFT(address _stakedNFT) external onlyAdmin {
        stakedNFT = IRewardNFT(_stakedNFT);
    }

    function setBase(uint256 _base) external onlyAdmin {
        base = _base;
    }

    function setStakeTokenTTL(uint256 _tokenId, uint256 _ttl) external onlyAdmin {
        uint256 oldTTL = stakeTokenTTLs[_tokenId];
        stakeTokenTTLs[_tokenId] = _ttl;

        emit SetStakeTokenTTL(_tokenId, _ttl, oldTTL);
    }

    function setBoostRatios(uint256[] calldata _ids, uint256[] calldata _ratios) external onlyAdmin {
        for (uint256 i = 0; i < _ids.length; ++i) {
            require(_ratios[i] != 0, "NFTBooster: !_ratios");
            boostRatios[_ids[i]] = _ratios[i];
        }
    }

    function setActiveBucket(uint256 _bucket, bool _active) external onlyAdmin {
        isActiveBucket[_bucket] = _active;
    }
}
