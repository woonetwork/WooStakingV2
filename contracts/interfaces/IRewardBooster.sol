// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWooStakingManager.sol";

interface IRewardBooster {
    event SetMPRewarder(address indexed rewarder);
    event SetAutoCompounder(address indexed compounder);
    event SetNFTBooster(address indexed nftBooster);

    event SetVolumeBR(uint256 newBr);
    event SetTvlBR(uint256 newBr);
    event SetAutoCompoundBR(uint256 newBr);

    function boostRatio(address _user) external view returns (uint256);

    function base() external view returns (uint256);
}
