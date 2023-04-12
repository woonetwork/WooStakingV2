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

import {NonblockingLzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IWooStakingManager} from "./interfaces/IWooStakingManager.sol";
import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {TransferHelper} from "./util/TransferHelper.sol";

contract WooStakingController is NonblockingLzApp, BaseAdminOperation {
    // --------------------- Events --------------------- //
    event StakeOnController(address indexed user, uint256 amount);
    event UnstakeOnController(address indexed user, uint256 amount);
    event SetAutoCompoundOnController(address indexed user, bool flag);
    event CompoundMPOnController(address indexed user);
    event CompoundAllOnController(address indexed user);
    event SetStakingManagerOnController(address indexed manager);

    uint8 public constant ACTION_STAKE = 1;
    uint8 public constant ACTION_UNSTAKE = 2;
    uint8 public constant ACTION_SET_AUTO_COMPOUND = 3;
    uint8 public constant ACTION_COMPOUND_MP = 4;
    uint8 public constant ACTION_COMPOUND_ALL = 5;

    IWooStakingManager public stakingManager;

    constructor(address _endpoint, address _stakingManager) NonblockingLzApp(_endpoint) {
        stakingManager = IWooStakingManager(_stakingManager);
    }

    // --------------------- LZ Receive Message Functions --------------------- //

    function _nonblockingLzReceive(
        uint16, // _srcChainId
        bytes memory, // _srcAddress
        uint64, // _nonce
        bytes memory _payload
    ) internal override whenNotPaused {
        (address user, uint8 action, uint256 amount) = abi.decode(_payload, (address, uint8, uint256));
        if (action == ACTION_STAKE) {
            _stake(user, amount);
        } else if (action == ACTION_UNSTAKE) {
            _unstake(user, amount);
        } else if (action == ACTION_SET_AUTO_COMPOUND) {
            _setAutoCompound(user, amount > 0);
        } else if (action == ACTION_COMPOUND_MP) {
            _compoundMP(user);
        } else if (action == ACTION_COMPOUND_ALL) {
            _compoundAll(user);
        } else {
            // Unsupported actions, ignore it
        }
    }

    // --------------------- Business Logic Functions --------------------- //

    function _stake(address _user, uint256 _amount) internal {
        stakingManager.stakeWoo(_user, _amount);
        emit StakeOnController(_user, _amount);
    }

    function _unstake(address _user, uint256 _amount) internal {
        stakingManager.unstakeWoo(_user, _amount);
        emit UnstakeOnController(_user, _amount);
    }

    function _setAutoCompound(address _user, bool _flag) internal {
        stakingManager.setAutoCompound(_user, _flag);
        emit SetAutoCompoundOnController(_user, _flag);
    }

    function _compoundMP(address _user) internal {
        stakingManager.compoundMP(_user);
        emit CompoundMPOnController(_user);
    }

    function _compoundAll(address _user) internal {
        stakingManager.compoundAll(_user);
        emit CompoundAllOnController(_user);
    }

    // --------------------- Admin Functions --------------------- //

    function setStakingManager(address _manager) external onlyAdmin {
        stakingManager = IWooStakingManager(_manager);
        // NOTE: don't forget to add self as the admin of stakingManager and autoCompounder
        emit SetStakingManagerOnController(_manager);
    }

    receive() external payable {}
}
