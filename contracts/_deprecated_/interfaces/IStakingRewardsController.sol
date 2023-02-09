// SPDX-License-Identifier: MIT licensed

pragma solidity ^0.8.4;

interface IStakingRewardsController {
    // Views
    function totalSupply() external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);

    function balanceOf(address _user, uint16 chainId) external view returns (uint256);
}
