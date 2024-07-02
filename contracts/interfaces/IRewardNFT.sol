// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IRewardNFT is IERC1155 {
    function mint(address _user, uint256 _tokenId, uint256 _amount) external;

    function burn(address _user, uint256 _tokenId, uint256 _amount) external;

    function getAllTokenIds() external view returns (uint256[] memory allTokenIds);
}
