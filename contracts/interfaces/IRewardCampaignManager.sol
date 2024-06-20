// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewardCampaignManager {
    function claim(uint256 _campaignId) external returns (uint128 count);

    function isClaimable(uint256 _campaignId, uint256 _tokenId, address _user) external view returns (bool claimable);

    function isClaimed(uint256 _campaignId, uint256 _tokenId, address _user) external view returns (bool claimed);
}
