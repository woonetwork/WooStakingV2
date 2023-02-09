// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./MintableBaseToken.sol";

contract EsWoo is MintableBaseToken {
    constructor() MintableBaseToken("Escrowed Woo", "esWoo", 0) {}

    function id() external pure returns (string memory _name) {
        return "esWoo";
    }
}
