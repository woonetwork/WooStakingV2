// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./MintableBaseToken.sol";

contract BnWoo is MintableBaseToken {
    constructor() MintableBaseToken("Bonus Woo", "bnWoo", 0) {}

    function id() external pure returns (string memory _name) {
        return "bnWoo";
    }
}
