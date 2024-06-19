// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTBoosterV2 {
    event SetStakeTokenTTL(uint256 tokenId, uint256 newTTL, uint256 oldTTL);

    struct StakeShortToken {
        uint256 tokenId;
        uint256 timestamp;
    }

    function base() external view returns (uint256);

    function stakeShortNFT(uint256 _tokenId, uint256 _index) external;

    function boostRatio(address _user) external view returns (uint256 compoundRatio, uint256[3] memory stakeTokenIds);

    function getUserTier(address _user) external view returns (uint256 userTier);
}
