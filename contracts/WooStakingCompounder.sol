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

import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {TransferHelper} from "./util/TransferHelper.sol";

import {IWooStakingManager} from "./interfaces/IWooStakingManager.sol";
import {IWooStakingCompounder} from "./interfaces/IWooStakingCompounder.sol";

contract WooStakingCompounder is IWooStakingCompounder, BaseAdminOperation {
    event AddUser(address indexed user);
    event RemoveUser(address indexed user);
    event RemoveAbortedInCooldown(address indexed user);
    event SetStakingManagerOnCompounder(address indexed manager);
    event SetCooldownDuration(uint256 duration);

    using EnumerableSet for EnumerableSet.AddressSet;

    IWooStakingManager public stakingManager;

    mapping(address => uint256) public lastAddedTs;

    uint256 public cooldownDuration;

    EnumerableSet.AddressSet private users;

    constructor(address _stakingManager) {
        stakingManager = IWooStakingManager(_stakingManager);
        cooldownDuration = 7 days;
    }

    function addUser() external {
        _addUser(msg.sender);
    }

    function addUser(address _user) external onlyAdmin {
        _addUser(_user);
    }

    function _addUser(address _user) internal {
        lastAddedTs[_user] = block.timestamp;
        users.add(_user);
        emit AddUser(_user);
    }

    function removeUser() external returns (bool removed) {
        removed = _removeUser(msg.sender);
    }

    function removeUser(address _user) external onlyAdmin returns (bool removed) {
        removed = _removeUser(_user);
    }

    function _removeUser(address _user) internal returns (bool removed) {
        if (!users.contains(_user)) {
            return false;
        }
        uint256 _ts = lastAddedTs[_user];
        if (_ts > 0 && block.timestamp > _ts && block.timestamp - _ts < cooldownDuration) {
            // Still in cooldown, abort the removing action
            emit RemoveAbortedInCooldown(_user);
            return false;
        }
        users.remove(_user);
        lastAddedTs[_user] = 0;
        emit RemoveUser(_user);
        return true;
    }

    function addUsers(address[] memory _users) external onlyAdmin {
        unchecked {
            uint256 len = _users.length;
            for (uint256 i = 0; i < len; ++i) {
                _addUser(_users[i]);
            }
        }
    }

    function removeUsers(address[] memory _users) external onlyAdmin {
        unchecked {
            uint256 len = _users.length;
            for (uint256 i = 0; i < len; ++i) {
                _removeUser(_users[i]);
            }
        }
    }

    function compoundAll() external onlyAdmin {
        stakingManager.compoundAllForUsers(users.values());
    }

    function compound(uint256 start, uint256 end) external onlyAdmin {
        // range: [start, end)
        address[] memory _users = new address[](end - start);
        unchecked {
            for (uint256 i = start; i < end; ++i) {
                _users[i] = users.at(i);
            }
        }
        stakingManager.compoundAllForUsers(_users);
    }

    function allUsers() external view returns (address[] memory) {
        uint256 len = users.length();
        address[] memory _users = new address[](len);
        unchecked {
            for (uint256 i = 0; i < len; ++i) {
                _users[i] = users.at(i);
            }
        }
        return _users;
    }

    // range: [start, end)
    function allUsers(uint256 start, uint256 end) external view returns (address[] memory) {
        address[] memory _users = new address[](end - start);
        unchecked {
            for (uint256 i = start; i < end; ++i) {
                _users[i] = users.at(i);
            }
        }
        return _users;
    }

    function allUsersLength() external view returns (uint256) {
        return users.length();
    }

    function contains(address _user) external view returns (bool) {
        return users.contains(_user);
    }

    function setStakingManager(address _stakingManager) external onlyAdmin {
        stakingManager = IWooStakingManager(_stakingManager);
        emit SetStakingManagerOnCompounder(_stakingManager);
    }

    function setCooldownDuration(uint256 _duration) external onlyAdmin {
        cooldownDuration = _duration;
        emit SetCooldownDuration(_duration);
    }
}
