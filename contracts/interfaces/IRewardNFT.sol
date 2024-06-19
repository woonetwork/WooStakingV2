// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRewardNFT {
    function mint(address _user, uint256 _nftType, uint256 _amount) external;

    function getAllNFTTypes() external view returns (uint256[] memory allNFTTypes);
}
