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

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {NonblockingLzApp} from "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import {IWooStakingProxy} from "./interfaces/IWooStakingProxy.sol";
import {BaseAdminOperation} from "./BaseAdminOperation.sol";
import {TransferHelper} from "./util/TransferHelper.sol";

contract WooStakingProxy is IWooStakingProxy, NonblockingLzApp, BaseAdminOperation, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint8 public constant ACTION_STAKE = 1;
    uint8 public constant ACTION_UNSTAKE = 2;
    uint8 public constant ACTION_SET_AUTO_COMPOUND = 3;
    uint8 public constant ACTION_COMPOUND_MP = 4;
    uint8 public constant ACTION_COMPOUND_ALL = 5;

    uint16 public controllerChainId;
    address public controller;
    IERC20 public immutable want;

    mapping(uint8 => uint256) public actionToDstGas;
    mapping(address => uint256) public balances;

    constructor(
        address _endpoint,
        uint16 _controllerChainId,
        address _controller,
        address _want
    ) NonblockingLzApp(_endpoint) {
        require(_controller != address(0), "WooStakingProxy: !_controller");
        require(_want != address(0), "WooStakingProxy: !_want");

        controllerChainId = _controllerChainId;
        controller = _controller;
        want = IERC20(_want);

        actionToDstGas[ACTION_STAKE] = 600000;
        actionToDstGas[ACTION_UNSTAKE] = 600000;
        actionToDstGas[ACTION_SET_AUTO_COMPOUND] = 600000;
        actionToDstGas[ACTION_COMPOUND_MP] = 600000;
        actionToDstGas[ACTION_COMPOUND_ALL] = 600000;
    }

    function estimateFees(uint8 _action, uint256 _amount) public view returns (uint256 messageFee) {
        bytes memory payload = abi.encode(msg.sender, _action, _amount);
        bytes memory adapterParams = abi.encodePacked(uint16(2), actionToDstGas[_action], uint256(0), address(0x0));
        (messageFee, ) = lzEndpoint.estimateFees(controllerChainId, controller, payload, false, adapterParams);
    }

    function stake(uint256 _amount) external payable whenNotPaused nonReentrant {
        _stake(msg.sender, _amount);
    }

    function stake(address _user, uint256 _amount) external payable whenNotPaused nonReentrant {
        _stake(_user, _amount);
    }

    function _stake(address _user, uint256 _amount) private {
        want.safeTransferFrom(msg.sender, address(this), _amount);
        balances[_user] += _amount;

        emit StakeOnProxy(_user, _amount);
        _sendMessage(_user, ACTION_STAKE, _amount);
    }

    function unstake(uint256 _amount) external payable whenNotPaused nonReentrant {
        _unstake(msg.sender, _amount);
    }

    function unstakeAll() external payable whenNotPaused nonReentrant {
        _unstake(msg.sender, balances[msg.sender]);
    }

    function _unstake(address user, uint256 _amount) private {
        require(balances[user] >= _amount, "WooStakingProxy: !BALANCE");
        balances[user] -= _amount;
        want.safeTransfer(user, _amount);
        emit UnstakeOnProxy(user, _amount);
        _sendMessage(user, ACTION_UNSTAKE, _amount);
    }

    function setAutoCompound(bool _flag) external payable whenNotPaused nonReentrant {
        emit SetAutoCompoundOnProxy(msg.sender, _flag);
        _sendMessage(msg.sender, ACTION_SET_AUTO_COMPOUND, _flag ? 1 : 0);
    }

    function compoundMP() external payable whenNotPaused nonReentrant {
        address user = msg.sender;
        emit CompoundMPOnProxy(user);
        _sendMessage(user, ACTION_COMPOUND_MP, 0);
    }

    function compoundAll() external payable whenNotPaused nonReentrant {
        address user = msg.sender;
        emit CompoundAllOnProxy(user);
        _sendMessage(user, ACTION_COMPOUND_ALL, 0);
    }

    // --------------------- LZ Related Functions --------------------- //

    function _sendMessage(address user, uint8 _action, uint256 _amount) internal {
        require(msg.value > 0, "WooStakingProxy: !msg.value");

        bytes memory payload = abi.encode(user, _action, _amount);
        bytes memory adapterParams = abi.encodePacked(uint16(2), actionToDstGas[_action], uint256(0), address(0x0));

        _lzSend(
            controllerChainId, // destination chainId
            payload, // abi.encode()'ed bytes: (action, amount)
            payable(user), // refund address (LayerZero will refund any extra gas back to caller of send()
            address(0x0), // _zroPaymentAddress
            adapterParams, // https://layerzero.gitbook.io/docs/evm-guides/advanced/relayer-adapter-parameters
            msg.value // _nativeFee
        );
    }

    function _nonblockingLzReceive(
        uint16 /*_srcChainId*/,
        bytes memory /*_srcAddress*/,
        uint64 _nonce,
        bytes memory _payload
    ) internal override whenNotPaused {}

    // --------------------- Admin Functions --------------------- //

    function setController(address _controller) external onlyAdmin {
        controller = _controller;
    }

    function setControllerChainId(uint16 _chainId) external onlyAdmin {
        controllerChainId = _chainId;
    }

    function setGasForAction(uint8 _action, uint256 _gas) public onlyAdmin {
        actionToDstGas[_action] = _gas;
    }

    receive() external payable {}
}
