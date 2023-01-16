//SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IWooStakingNFT.sol";

contract PlutoNFT is ERC721, ReentrancyGuard, IWooStakingNFT, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenCounter;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MINTING_FEE = 0.01 ether;
    uint256 public constant BASE_BOOSTING_MULTIPLIER = 1e6;
    uint256 public constant BOOSTING_AMOUNT = (3 * BASE_BOOSTING_MULTIPLIER) / 2; // 150%
    uint256 public constant BOOSTING_DURATION = 2419200; // 1 month
    address public stakingManager;

    modifier onlyTokenOwner(uint256 tokenId) {
        require(_msgSender() == ownerOf(tokenId), "Only token owner");
        _;
    }

    modifier onlyManager() {
        require(_msgSender() == stakingManager, "Only manager");
        _;
    }

    constructor(address _stakingManager) ERC721("WooFi PlutoNFT", "WP-NFT") {
        require(_stakingManager != address(0), "Invalid address");
        stakingManager = _stakingManager;
    }

    function safeMint() external payable nonReentrant {
        require(msg.value >= MINTING_FEE, "Insufficient amount");
        uint256 tokenId = _tokenCounter.current();
        require(tokenId < MAX_SUPPLY, "Max supply reached");
        _safeMint(_msgSender(), tokenId);
        _tokenCounter.increment();
    }

    function setManager(address _stakingManager) external onlyOwner {
        require(_stakingManager != address(0), "Invalid address");
        stakingManager = _stakingManager;

        emit StakingManagerSet(stakingManager);
    }

    function consume(uint256 _tokenId) external onlyManager nonReentrant {
        _burn(_tokenId);
    }

    function getEffect(uint256 tokenId) public view returns (uint256 amount, uint256 duration) {
        if (_exists(tokenId)) {
            amount = BOOSTING_AMOUNT;
            duration = BOOSTING_DURATION;
        }
    }

    function totalSupply() external view override returns (uint256) {
        return _tokenCounter.current();
    }
}
