// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IWooStakingManager {
    /**
     * @dev Emitted when `account` has new boosting effects with `amount`
     * and `duration by consuming NFTs.
     */
    event BoostingEffectsUpdated(
        address account,
        uint256 amount,
        uint256 duration
    );

    /**
     * @dev Emitted when a new `nft` contract is added.
     */
    event ContractAdded(address nft);

    /**
     * @dev Consumes a NFT and boost multiplier points generation.
     */
    function consumeNFTAndBoost(uint256 tokenId, address nft) external;
}
