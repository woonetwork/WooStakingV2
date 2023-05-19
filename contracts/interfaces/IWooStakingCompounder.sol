// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWooStakingCompounder {
    function compoundAll() external;

    function compound(uint256 start, uint256 end) external;

    function contains(address _user) external view returns (bool);

    function addUser(address _user) external;

    function removeUser(address _user) external returns (bool removed);

    function removeUserIfNeeded(
        address _user,
        uint256 wooBalance,
        uint256 autoCompThreshold
    ) external returns (bool removed);
}
