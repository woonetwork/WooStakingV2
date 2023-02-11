// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../util/TransferHelper.sol";

import "../interfaces/IRewardBooster.sol";
import "../interfaces/IRewarder.sol";
import "../interfaces/IWooStakingManager.sol";

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardBooster is IRewardBooster, Ownable {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public boostRatio;

    mapping(address => bool) public isAdmin;

    IRewarder mpRewarder;

    constructor(address _mpRewarder) {
        mpRewarder = IRewarder(_mpRewarder);
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || isAdmin[msg.sender], "WooStakingManager: !admin");
        _;
    }

    function setRatios(address[] memory users, uint256[] memory ratios) external onlyAdmin {
        unchecked {
            for (uint256 i = 0; i < users.length; ++i) {
                boostRatio[users[i]] = ratios[i];
            }
        }
    }

    function setRatio(address[] memory users, uint256 ratio) external onlyAdmin {
        unchecked {
            for (uint256 i = 0; i < users.length; ++i) {
                // TODO: check the ratio difference?

                mpRewarder.updateRewardForUser(users[i]);
                boostRatio[users[i]] = ratio;
            }
        }
    }

    // --------------------- Admin Functions --------------------- //

    function setAdmin(address addr, bool flag) external onlyAdmin {
        isAdmin[addr] = flag;
    }

    function inCaseTokenGotStuck(address stuckToken) external onlyOwner {
        if (stuckToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        } else {
            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }
}
