// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IRewardBooster} from "../interfaces/IRewardBooster.sol";

import {IRewarder} from "../interfaces/IRewarder.sol";
import {BaseAdminOperation} from "../BaseAdminOperation.sol";
import {TransferHelper} from "../util/TransferHelper.sol";

contract RewardBooster is IRewardBooster, BaseAdminOperation {
    mapping(address => uint256) public boostRatio;

    IRewarder mpRewarder;

    constructor(address _mpRewarder) {
        mpRewarder = IRewarder(_mpRewarder);
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
}
