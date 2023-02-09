// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDC is IERC20, ERC20, Ownable {
    constructor() ERC20("USDC", "USDC") {
        _mint(_msgSender(), 1_000_000_000 * 1e18);
    }
}
