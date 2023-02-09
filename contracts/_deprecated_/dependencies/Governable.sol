// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";

contract Governable is Context {
    address public gov;

    constructor() {
        gov = _msgSender();
    }

    modifier onlyGov() {
        require(_msgSender() == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}
