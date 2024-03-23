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

contract NftBooster is IERC1155Receiver, BaseAdminOperation {
    event SetStakeTtl(uint256 newTtl, uint256 oldTtl);

    // only applied to controller chain
    uint256 public autoCompoundBR;

    address public immutable stakedNft;

    uint256 public base; // Default: 10000th, 100: 1%, 5000: 50%

    uint256 public stakeTtl; // Default: 10000th, 100: 1%, 5000: 50%

    mapping(uint256 => uint256) public boostRatios; // token_id => boost ratio

    mapping(address => uint256) public lastStakeTs; // user_address => last stake timestamp
    mapping(address => uint256) public lastStakeTokenIds; // user_address => last stake token id

    constructor(address _stakedNft) {
        base = 10000;
        stakeTtl = 7 days;
        stakedNft = _stakedNft;
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
        // if (nftContract.burnable(_tokenId)) {
        // }
        nftContract.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "0x0");

        lastStakeTs[msg.sender] = block.timestamp;
        lastStakeTokenIds[msg.sender] = _tokenId;
    }

    function boostRatio(address _user) external view returns (uint256) {
        if ((block.timestamp - lastStakeTs[_user]) > stakeTtl) {
            return base;
        }

        uint256 id = lastStakeTokenIds[_user];
        return boostRatios[id] == 0 ? base : boostRatios[id];
    }

    function setStakeTtl(uint256 _ttl) external onlyAdmin {
        uint256 oldTtl = stakeTtl;
        stakeTtl = _ttl;
        emit SetStakeTtl(_ttl, oldTtl);
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
}
