// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

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
    uint8 public constant ACTION_COMPOUND = 3;

    uint16 public override controllerChainId;
    address public override controller;
    IERC20 public immutable override want;

    mapping(uint8 => uint256) public actionToDstGas;
    mapping(address => uint256) public override balances;

    constructor(
        address _endpoint,
        uint16 _controllerChainId,
        address _controller,
        address _want
    ) NonblockingLzApp(_endpoint) {
        require(_controller != address(0), "WooStakingProxy: invalid controller address");
        require(_want != address(0), "WooStakingProxy: invalid staking token address");

        controllerChainId = _controllerChainId;
        controller = _controller;
        want = IERC20(_want);

        actionToDstGas[ACTION_STAKE] = 200000;
        actionToDstGas[ACTION_UNSTAKE] = 200000;
        actionToDstGas[ACTION_COMPOUND] = 200000;
    }

    function estimateFees(uint8 _action, uint256 _amount) public view override returns (uint256 messageFee) {
        bytes memory payload = abi.encode(msg.sender, _action, _amount);
        bytes memory adapterParams = abi.encodePacked(uint16(2), actionToDstGas[_action], uint256(0), address(0x0));
        (messageFee, ) = lzEndpoint.estimateFees(controllerChainId, controller, payload, false, adapterParams);
    }

    function stake(uint256 _amount) external payable override whenNotPaused nonReentrant {
        _stake(msg.sender, _amount);
    }

    function stake(address _user, uint256 _amount) external payable override whenNotPaused nonReentrant {
        _stake(_user, _amount);
    }

    function _stake(address _user, uint256 _amount) private {
        want.safeTransferFrom(_user, address(this), _amount);
        balances[_user] += _amount;

        emit StakeOnProxy(_user, _amount);
        _sendMessage(_user, ACTION_STAKE, _amount);
    }

    function unstake(uint256 _amount) external payable override whenNotPaused nonReentrant {
        _unstake(msg.sender, _amount);
    }

    function unstakeAll() external payable override whenNotPaused nonReentrant {
        _unstake(msg.sender, balances[msg.sender]);
    }

    function _unstake(address user, uint256 _amount) private {
        require(balances[user] >= _amount, "WooStakingProxy: !BALANCE");
        balances[user] -= _amount;
        want.safeTransfer(user, _amount);
        emit WithdrawOnProxy(user, _amount);
        _sendMessage(user, ACTION_UNSTAKE, _amount);
    }

    function compound() external payable override whenNotPaused nonReentrant {
        address user = msg.sender;
        emit CompoundOnProxy(user);
        _sendMessage(user, ACTION_COMPOUND, 0);
    }

    // --------------------- LZ Related Functions --------------------- //

    function _sendMessage(address user, uint8 _action, uint256 _amount) internal {
        require(msg.value > 0, "WooStakingProxy: msg.value is 0");

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
