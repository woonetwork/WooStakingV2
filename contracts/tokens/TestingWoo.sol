// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./MintableBaseToken.sol";

contract TestingWoo is MintableBaseToken {
    constructor() MintableBaseToken("Testing Woo", "tWoo", 0) {}

    function id() external pure returns (string memory _name) {
        return "tWoo";
    }
}
