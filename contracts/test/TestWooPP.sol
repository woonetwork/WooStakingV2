// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IWooPPV2.sol";
import "../util/TransferHelper.sol";

contract TestWooPP is IWooPPV2 {
    mapping(address => uint256) public prices; // token -> price
    function setPrice(address _token, uint256 _price) external {
        prices[_token] = _price;
    }

    function quoteToken() external view returns (address) {}
    function poolSize(address token) external view returns (uint256) {}
    function tryQuery(address fromToken, address toToken, uint256 fromAmount) external view returns (uint256 toAmount){}
    function query(address fromToken, address toToken, uint256 fromAmount) external view returns (uint256 toAmount) {}
    function deposit(address token, uint256 amount) external {}

    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 /*minToAmount*/,
        address /*to*/,
        address /*rebateTo*/
    ) external returns (uint256 realToAmount) {
        // 5, 7000
        realToAmount = (fromAmount * prices[fromToken]) / prices[toToken];
        console.log("fromToken: %s fromAmount: %s realToAmount: %s",
            fromToken, fromAmount, realToAmount);

        // NOTE: like uniswap pair, trade proactively pushes the fund here.
        // TransferHelper.safeTransferFrom(fromToken, msg.sender, to, fromAmount);

        TransferHelper.safeTransfer(toToken, msg.sender, realToAmount);
    }

    function getSwapAmount (address fromToken, address toToken, uint256 fromAmount) external view returns (uint256 realToAmount) {
        realToAmount = (fromAmount * prices[fromToken]) / prices[toToken];
    }
}