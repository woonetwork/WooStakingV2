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
    event StakeOnController(address indexed user, uint256 amount);
    event WithdrawOnController(address indexed user, uint256 amount);
    event CompoundOnController(address indexed user);

    uint8 public constant ACTION_STAKE = 1;
    uint8 public constant ACTION_UNSTAKE = 2;
    uint8 public constant ACTION_COMPOUND = 3;

    IWooStakingManager public stakingManager;

    mapping(address => uint256) public balances;

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
            _withdraw(user, amount);
        } else if (action == ACTION_COMPOUND) {
            _compound(user);
        } else {
            revert("WooStakingController: !action");
        }
    }

    // --------------------- Business Logic Functions --------------------- //

    function _stake(address _user, uint256 _amount) private {
        stakingManager.stakeWoo(_user, _amount);
        balances[_user] += _amount;
        emit StakeOnController(_user, _amount);
    }

    function _withdraw(address _user, uint256 _amount) private {
        balances[_user] -= _amount;
        stakingManager.unstakeWoo(_user, _amount);
        emit WithdrawOnController(_user, _amount);
    }

    function _compound(address _user) private {
        stakingManager.compoundAll(_user);
        emit CompoundOnController(_user);
    }

    // --------------------- Admin Functions --------------------- //

    function setStakingManager(address _manager) external onlyAdmin {
        stakingManager = IWooStakingManager(_manager);
    }

    function syncBalance(address _user, uint256 _balance) external onlyAdmin {
        // TODO: handle the balance and reward update
    }

    receive() external payable {}
}
