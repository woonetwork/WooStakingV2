// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import "./util/TransferHelper.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

contract WooStakingProxy is NonblockingLzApp, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint8 public constant ACTION_STAKE = 1;
    uint8 public constant ACTION_WITHDRAW = 2;
    uint8 public constant ACTION_COMPOUND = 3;

    uint16 public controllerChainId = 12;
    address public controller;
    IERC20 public immutable want;

    mapping(uint8 => uint256) public actionToDstGas;
    mapping(address => uint256) public balances;
    mapping(address => bool) public isAdmin;

    event StakeOnProxy(address indexed user, uint256 amount);
    event WithdrawOnProxy(address indexed user, uint256 amount);
    event CompoundOnProxy(address indexed user);
    event AdminUpdated(address indexed addr, bool flag);

    modifier onlyAdmin() {
        require(msg.sender == owner() || isAdmin[msg.sender], "WooStakingProxy: !admin");
        _;
    }

    constructor(address _endpoint, address _controller, address _want) NonblockingLzApp(_endpoint) {
        transferOwnership(msg.sender);
        require(_controller != address(0), "WooStakingProxy: invalid controller address");
        require(_want != address(0), "WooStakingProxy: invalid staking token address");

        controller = _controller;
        want = IERC20(_want);

        actionToDstGas[ACTION_STAKE] = 280000;
        actionToDstGas[ACTION_WITHDRAW] = 360000;
        actionToDstGas[ACTION_COMPOUND] = 160000;
    }

    function estimateFees(uint8 _action, uint256 _amount) public view returns (uint256 messageFee) {
        bytes memory payload = abi.encode(msg.sender, _action, _amount);
        bytes memory adapterParams = abi.encodePacked(uint16(2), actionToDstGas[_action], uint256(0), address(0x0));
        (messageFee, ) = lzEndpoint.estimateFees(controllerChainId, controller, payload, false, adapterParams);
    }

    function stake(uint256 _amount) external payable whenNotPaused nonReentrant {
        address user = msg.sender;
        want.safeTransferFrom(user, address(this), _amount);
        balances[user] += _amount;

        emit StakeOnProxy(user, _amount);
        _sendMessage(user, ACTION_STAKE, _amount);
    }

    function withdraw(uint256 _amount) external payable whenNotPaused nonReentrant {
        _withdraw(msg.sender, _amount);
    }

    function withdrawAll() external payable whenNotPaused nonReentrant {
        _withdraw(msg.sender, balances[msg.sender]);
    }

    function _withdraw(address user, uint256 _amount) private {
        require(balances[user] >= _amount, "WooStakingProxy: !BALANCE");
        balances[user] -= _amount;
        want.safeTransfer(user, _amount);
        emit WithdrawOnProxy(user, _amount);
        _sendMessage(user, ACTION_WITHDRAW, _amount);
    }

    function compound() external payable whenNotPaused nonReentrant {
        address user = msg.sender;
        emit CompoundOnProxy(user);
        _sendMessage(user, ACTION_COMPOUND, 0);
    }

    // --------------------- LZ Related Functions --------------------- //

    function _sendMessage(address user, uint8 _action, uint256 _amount) internal {
        require(msg.value > 0, "WooStakingProxy: msg.value is 0");

        bytes memory payload = abi.encode(user, _action, _amount);
        bytes memory adapterParams = abi.encodePacked(uint16(2), actionToDstGas[_action], uint256(0), address(0x0));

        // TODO: confirmed this require is unnecessary
        // get the fees we need to pay to LayerZero for message delivery
        // (uint256 messageFee, ) = lzEndpoint.estimateFees(controllerChainId, controller, payload, false, adapterParams);
        // require(msg.value >= messageFee, "WooStakingProxy: msg.value < messageFee");

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

    function pause() public onlyAdmin {
        super._pause();
    }

    function unpause() public onlyAdmin {
        super._unpause();
    }

    function setAdmin(address addr, bool flag) external onlyAdmin {
        isAdmin[addr] = flag;
        emit AdminUpdated(addr, flag);
    }

    function setController(address _controller) external onlyAdmin {
        controller = _controller;
    }

    function setControllerChainId(uint16 _chainId) external onlyAdmin {
        controllerChainId = _chainId;
    }

    function setGasForAction(uint8 _action, uint256 _gas) public onlyAdmin {
        actionToDstGas[_action] = _gas;
    }

    function inCaseTokenGotStuck(address stuckToken) external onlyOwner {
        if (stuckToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        } else {
            // TODO: remove me when releasing to prod
            // require(stuckToken != want, "WooStakingProxy: !want");

            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }

    receive() external payable {}
}
