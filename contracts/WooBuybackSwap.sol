// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {ILBRouter} from "./interfaces/ILBRouter.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {TransferHelper} from "./util/TransferHelper.sol";

contract WooBuybackSwap is BaseAdminOperation {
    event SetLBRouterOnBuyBack(address indexed lbrouter);

    /* ----- Constant variables ----- */

    // Erc20 address
    address public constant USDC_ADDR = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant USDCE_ADDR = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant WETH_ADDR = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant WOO_ADDR = 0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b;
    address public constant ARB_ADDR = 0x912CE59144191C1204E64559FE8253a0e49E6548;

    /* ----- State variables ----- */
    address public lbrouter;
    mapping(address => ILBRouter.Path) private routerPath;
    mapping(address => address) public oracles;

    uint256 public slippage; // 1 in 10000th: e.g. 100 = 1%; 50 = 0.5%, 10 = 0.1%
    uint256 public constant SLIP_BASE = 10000;
    uint256 public constant ORACLE_TTL = 60 minutes;

    constructor(address _lbrouter) {
        // arb contract: https://arbiscan.io/address/0xb4315e873dbcf96ffd0acd8ea43f689d8c20fb30#code
        lbrouter = _lbrouter;
        slippage = 50;

        _initRouterPath();
        _initOracles();
    }

    function _initRouterPath() internal {
        ILBRouter.Path memory usdcPath;

        uint256[] memory pairBinSteps = new uint256[](2);
        pairBinSteps[0] = 15;
        pairBinSteps[1] = 25;
        ILBRouter.Version[] memory versions = new ILBRouter.Version[](2);
        versions[0] = ILBRouter.Version.V2_1;
        versions[1] = ILBRouter.Version.V2_1;
        IERC20[] memory tokenPath = new IERC20[](3);
        tokenPath[0] = IERC20(USDC_ADDR);
        tokenPath[1] = IERC20(WETH_ADDR);
        tokenPath[2] = IERC20(WOO_ADDR);

        usdcPath.pairBinSteps = pairBinSteps;
        usdcPath.versions = versions;
        usdcPath.tokenPath = tokenPath;
        routerPath[USDC_ADDR] = usdcPath;

        ILBRouter.Path memory arbPath;
        tokenPath[0] = IERC20(ARB_ADDR);
        tokenPath[1] = IERC20(WETH_ADDR);
        tokenPath[2] = IERC20(WOO_ADDR);

        arbPath.pairBinSteps = pairBinSteps;
        arbPath.versions = versions;
        arbPath.tokenPath = tokenPath;
        routerPath[ARB_ADDR] = arbPath;
    }

    function _initOracles() internal {
        oracles[USDC_ADDR] = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
        oracles[USDCE_ADDR] = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
        oracles[WETH_ADDR] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
        oracles[ARB_ADDR] = 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6;

        oracles[WOO_ADDR] = 0x5e2b5C5C07cCA3437c4D724225Bb42c7E55d1597;
    }

    function setLBRouter(address _lbrouter) external onlyAdmin {
        lbrouter = _lbrouter;
        emit SetLBRouterOnBuyBack(_lbrouter);
    }

    function setRouterPath(address fromToken, ILBRouter.Path calldata path) external onlyAdmin {
        require(path.tokenPath.length > 0, "token swap path should be valid!");
        routerPath[fromToken] = path;
    }

    // fromToken = $usdc or $arb
    // toToken = woo
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        address to,
        address /*rebateTo*/
    ) external returns (uint256 realToAmount) {
        require(IERC20(fromToken).balanceOf(address(this)) >= fromAmount);
        require(routerPath[fromToken].tokenPath.length > 0, "Only support swap usdc or arb!");
        require(toToken == WOO_ADDR, "Only support swap to woo!");
        require(minToAmount >= 0, "minToAmount should be equal or greater than 0!");

        TransferHelper.safeApprove(fromToken, lbrouter, fromAmount);
        realToAmount = ILBRouter(lbrouter).swapExactTokensForTokens(
            fromAmount,
            _minWooAmount(fromToken, fromAmount),
            routerPath[fromToken],
            to,
            block.timestamp + 600
        );
    }

    // Min woo token amount, based on Chainlink oracle price.
    function _minWooAmount(address _fromToken, uint256 _fromAmount) internal view returns (uint256 wooAmount) {
        AggregatorV3Interface baseOracle = AggregatorV3Interface(oracles[WOO_ADDR]);
        AggregatorV3Interface quoteOracle = AggregatorV3Interface(oracles[_fromToken]);

        require(baseOracle.decimals() == quoteOracle.decimals(), "!oracle_price_decimal");

        (, int256 rawBaseRefPrice, , uint256 baseUpdatedAt, ) = AggregatorV3Interface(baseOracle).latestRoundData();
        (, int256 rawQuoteRefPrice, , uint256 quoteUpdatedAt, ) = AggregatorV3Interface(quoteOracle).latestRoundData();
        require(baseUpdatedAt >= block.timestamp - ORACLE_TTL, "!baseUpdatedAt");
        require(quoteUpdatedAt >= block.timestamp - ORACLE_TTL, "!quoteUpdatedAt");
        uint256 baseRefPrice = uint256(rawBaseRefPrice);
        uint256 quoteRefPrice = uint256(rawQuoteRefPrice);

        return (((_fromAmount * quoteRefPrice) / baseRefPrice) * slippage) / SLIP_BASE;
    }
}
