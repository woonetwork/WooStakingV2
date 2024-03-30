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

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {ILBRouter} from "./interfaces/ILBRouter.sol";
import {TransferHelper} from "./util/TransferHelper.sol";

contract WooBuybackSwap is BaseAdminOperation {
    event SetUniRouterOnBuyBack(address indexed unirouter);
    using SafeERC20 for IERC20;

    address public unirouter;
    mapping(address => ILBRouter.Path) private routerPath;

    constructor(address _unirouter) {
        unirouter = _unirouter;
        // usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
        // weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
        // woo = 0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b
        // arb = 0x912CE59144191C1204E64559FE8253a0e49E6548

        // usdc
        ILBRouter.Path memory usdcPath;

        uint256[] memory pairBinSteps = new uint256[](2);
        pairBinSteps[0] = 15;
        pairBinSteps[1] = 25;
        ILBRouter.Version[] memory versions = new ILBRouter.Version[](2);
        versions[0] = ILBRouter.Version.V2_1;
        versions[1] = ILBRouter.Version.V2_1;
        IERC20[] memory tokenPath = new IERC20[](3);
        tokenPath[0] = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        tokenPath[1] = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        tokenPath[2] = IERC20(0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b);

        usdcPath.pairBinSteps = pairBinSteps;
        usdcPath.versions = versions;
        usdcPath.tokenPath = tokenPath;
        routerPath[address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831)] = usdcPath;

        // arb
        ILBRouter.Path memory arbPath;
        tokenPath[0] = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
        tokenPath[1] = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        tokenPath[2] = IERC20(0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b);

        arbPath.pairBinSteps = pairBinSteps;
        arbPath.versions = versions;
        arbPath.tokenPath = tokenPath;
        routerPath[address(0x912CE59144191C1204E64559FE8253a0e49E6548)] = arbPath;
    }

    function setUniRouter(address _unirouter) external onlyAdmin {
        unirouter = _unirouter;
        emit SetUniRouterOnBuyBack(_unirouter);
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
        require(toToken == address(0xcAFcD85D8ca7Ad1e1C6F82F651fA15E33AEfD07b), "Only support swap to woo!");
        require(minToAmount >= 0, "minToAmount should be equal or greater than 0!");

        TransferHelper.safeApprove(fromToken, unirouter, fromAmount);
        realToAmount = ILBRouter(unirouter).swapExactTokensForTokens(
            fromAmount,
            minToAmount,
            routerPath[fromToken],
            to,
            block.timestamp + 600
        );
    }
}
