// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IWooStakingNFT is IERC721 {
    /**
     * @dev Emitted when `stakingManager` contract has been
     * set for a NFT contract.
     */
    event StakingManagerSet(address stakingManager);

    /**
     * @dev Consumes a nft with `tokenId`.
     */
    function consume(uint256 tokenId) external;

    /**
     * @dev Returns the current total supply of NFTs.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the boosting `amount` and `duration` for an
     * NFT with `tokenId`. The only requirement is the NFT with
     * `tokenId` must exist.
     */
    function getEffect(uint256 tokenId)
        external
        view
        returns (uint256 amount, uint256 duration);
}
