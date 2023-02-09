// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./dependencies/Governable.sol";

contract VoidRewardRouter is ReentrancyGuard, Governable {
    function stakeTokenForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {}

    function unstakeTokenForAccount(address _user, uint256 _amount) external nonReentrant {}

    function compoundForAccount(address _account) external nonReentrant onlyGov {}
}
