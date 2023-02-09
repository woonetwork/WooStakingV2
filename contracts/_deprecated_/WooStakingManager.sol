//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IWooStakingManager.sol";
import "./interfaces/IBonusTracker.sol";
import "./interfaces/IWooStakingNFT.sol";

contract WooStakingManager is IWooStakingManager, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private nftSet;

    address public bnTokenRewardTracker;
    bool public initialized;

    constructor(address _bnTokenRewardTracker) {
        require(_bnTokenRewardTracker != address(0), "Invalid address");
        bnTokenRewardTracker = _bnTokenRewardTracker;
    }

    function addNFTContract(address _nft) external onlyOwner {
        require(_nft != address(0), "Manager: invalid address");
        nftSet.add(_nft);

        emit ContractAdded(_nft);
    }

    function consumeNFTAndBoost(uint256 tokenId, address nft) external {
        require(nft != address(0), "invalid address");
        require(nftSet.contains(nft), "Not supported");
        address caller = _msgSender();
        require(_ownerOf(tokenId, nft) == caller, "Not the owner");

        (uint256 amount, uint256 duration) = _retrieveNFTEffects(tokenId, nft);
        _addBoostingEffects(caller, amount, duration);
        _consume(tokenId, nft);
    }

    function _addBoostingEffects(address account, uint256 amount, uint256 duration) private {
        IBonusTracker(bnTokenRewardTracker).updateBoostingInfo(account, amount, block.timestamp + duration);

        emit BoostingEffectsUpdated(account, amount, duration);
    }

    function _ownerOf(uint256 tokenId, address nft) private view returns (address) {
        return IWooStakingNFT(nft).ownerOf(tokenId);
    }

    function _retrieveNFTEffects(uint256 tokenId, address nft) private view returns (uint256, uint256) {
        return IWooStakingNFT(nft).getEffect(tokenId);
    }

    function _consume(uint256 tokenId, address nft) private {
        IWooStakingNFT(nft).consume(tokenId);
    }
}
