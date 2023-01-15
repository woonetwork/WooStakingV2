// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroUserApplicationConfig.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./LZ/LzApp.sol";
import "./LZ/NonBlockingLzApp.sol";
import "./Signer.sol";

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

contract WooStakingProxy is NonblockingLzApp, Signer, Pausable {
    using ERC165Checker for address;
    using SafeERC20 for IERC20;

    uint8 public constant ACTION_STAKE = 1;
    uint8 public constant ACTION_WITHDRAW = 2;
    uint8 public constant ACTION_CLAIM = 3;

    uint16 public controllerChainId = 12;
    address public controller;
    IERC20 public immutable want;

    struct GasAmounts {
        uint256 proxyWithdraw;
        uint256 proxyClaim;
        uint256 controllerStake;
        uint256 controllerWithdraw;
        uint256 controllerClaim;
    }

    GasAmounts public gasAmounts;
    mapping(uint64 => bool) private nonceRegistry;
    mapping(address => uint8) public actionInQueue;
    mapping(address => bytes) public signatures;
    mapping(address => uint256) public balances;

    // wallet address --> is admin
    mapping(address => bool) public isAdmin;

    event StakeInitiated(address indexed user, uint256 amount);
    event WithdrawalInitiated(address indexed user);
    event ClaimInitiated(address indexed user);

    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event AdminUpdated(address indexed addr, bool flag);

    modifier notInQueue(address account) {
        require(actionInQueue[account] == 0, "StakingRewardsProxy: In queue already! Wait till the callback comes.");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || isAdmin[msg.sender], "WooPPV2: !admin");
        _;
    }

    constructor(address _endpoint, address _controller, address _want) NonblockingLzApp(_endpoint) {
        transferOwnership(msg.sender);
        require(_controller != address(0), "StakingRewardsProxy: invalid controller address");
        require(_want != address(0), "StakingRewardsProxy: invalid staking token address");

        controller = _controller;
        want = IERC20(_want);

        gasAmounts.proxyWithdraw = 260000;
        gasAmounts.proxyClaim = 240000;
        gasAmounts.controllerStake = 280000;
        gasAmounts.controllerWithdraw = 360000;
        gasAmounts.controllerClaim = 380000;
    }

    function estimateFees(
        uint8 _action,
        uint256 _amount,
        bytes memory _signature,
        uint256 controllerGas
    ) public view returns (uint256 messageFee) {
        bytes memory adapterParams = getAdapterParams(_action, controllerGas);

        bytes memory payload = abi.encode(msg.sender, _action, _amount, _signature);
        // get the fees we need to pay to LayerZero for message delivery
        (messageFee, ) = lzEndpoint.estimateFees(controllerChainId, controller, payload, false, adapterParams);
    }

    function getGasAmount(uint8 _action, bool _isProxy) internal view returns (uint256 gasAmount) {
        gasAmount = 0;
        if (_isProxy) {
            if (_action == ACTION_CLAIM) {
                gasAmount = gasAmounts.proxyClaim;
            } else if (_action == ACTION_WITHDRAW) {
                gasAmount = gasAmounts.proxyWithdraw;
            }
        } else {
            if (_action == ACTION_CLAIM) {
                gasAmount = gasAmounts.controllerClaim;
            } else if (_action == ACTION_WITHDRAW) {
                gasAmount = gasAmounts.controllerWithdraw;
            } else if (_action == ACTION_STAKE) {
                gasAmount = gasAmounts.controllerStake;
            }
        }
        require(gasAmount > 0, "StakingRewardsProxy: unable to retrieve gas amount");
    }

    function getAdapterParams(uint8 _action, uint256 controllerGas) internal view returns (bytes memory adapterParams) {
        if (_action == ACTION_STAKE) {
            uint16 version = 1;
            uint256 gasForDestinationLzReceive = getGasAmount(_action, false);
            adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
        } else {
            uint16 version = 2;
            uint256 gasForDestinationLzReceive = getGasAmount(_action, false);

            adapterParams = abi.encodePacked(version, gasForDestinationLzReceive, controllerGas, controller);
        }
    }

    function _sendMessage(uint8 _action, uint256 _amount, bytes memory _signature, uint256 controllerGas) internal {
        require(msg.value > 0, "StakingRewardsProxy: msg.value is 0");

        if (_action == ACTION_STAKE) {
            StakeData memory actionData = StakeData(_action, _amount);
            verify(msg.sender, actionData, _signature);
        } else {
            ClaimWithdrawData memory actionData = ClaimWithdrawData(_action);
            verify(msg.sender, actionData, _signature);
        }

        bytes memory payload = abi.encode(msg.sender, _action, _amount, _signature);

        // use adapterParams v1 to specify more gas for the destination
        bytes memory adapterParams = getAdapterParams(_action, controllerGas);

        // get the fees we need to pay to LayerZero for message delivery
        (uint256 messageFee, ) = lzEndpoint.estimateFees(controllerChainId, controller, payload, false, adapterParams);

        require(msg.value >= messageFee, "StakingRewardsProxy: msg.value < messageFee");

        _lzSend( // {value: messageFee} will be paid out of this contract!
            controllerChainId, // destination chainId
            payload, // abi.encode()'ed bytes
            payable(msg.sender), // refund address (LayerZero will refund any extra gas back to caller of send()
            address(0x0), // future param, unused for this example
            adapterParams // v1 adapterParams, specify custom destination gas qty
        );
    }

    function stake(uint256 _amount, bytes memory _signature) external payable whenNotPaused {
        want.safeTransferFrom(msg.sender, address(this), _amount);
        balances[msg.sender] += _amount;

        uint256 controllerGas = 0;
        emit StakeInitiated(msg.sender, _amount);
        _sendMessage(ACTION_STAKE, _amount, _signature, controllerGas);
    }

    function withdraw(
        uint256 _amount,
        bytes memory _signature,
        uint256 _controllerGas
    ) external payable whenNotPaused notInQueue(msg.sender) {
        require(balances[msg.sender] > _amount, "StakingRewardsProxy: Nothing to withdraw");
        balances[msg.sender] -= _amount;

        actionInQueue[msg.sender] = ACTION_WITHDRAW;
        signatures[msg.sender] = _signature;

        emit WithdrawalInitiated(msg.sender);
        _sendMessage(ACTION_WITHDRAW, _amount, _signature, _controllerGas);
    }

    function claim(
        bytes memory _signature,
        uint256 _controllerGas
    ) external payable whenNotPaused notInQueue(msg.sender) {
        actionInQueue[msg.sender] = ACTION_CLAIM;
        signatures[msg.sender] = _signature;
        uint256 amount = 0;
        emit ClaimInitiated(msg.sender);
        _sendMessage(ACTION_CLAIM, amount, _signature, _controllerGas);
    }

    function _nonblockingLzReceive(
        uint16 /*_srcChainId*/,
        bytes memory /*_srcAddress*/,
        uint64 _nonce,
        bytes memory _payload
    ) internal override whenNotPaused {
        require(!nonceRegistry[_nonce], "This nonce was already processed");

        (address payable target, uint256 rewardAmount, uint256 withdrawAmount, bytes memory signature) = abi.decode(
            _payload,
            (address, uint256, uint256, bytes)
        );

        ClaimWithdrawData memory actionData = ClaimWithdrawData(actionInQueue[target]);
        verify(target, actionData, signature);

        require(actionInQueue[target] != 0, "StakingRewardsProxy: No claim or withdrawal is in queue for this address");
        require(keccak256(signatures[target]) == keccak256(signature), "StakingRewardsProxy: Invalid signature");

        if (withdrawAmount > 0) {
            require(balances[target] > 0, "StakingRewardsProxy: Invalid withdrawal, no deposits done");
            require(
                want.balanceOf(address(this)) >= withdrawAmount,
                "StakingRewardsProxy: Insufficient proxy token balance"
            );

            want.safeTransfer(target, withdrawAmount);
            balances[target] = balances[target] - withdrawAmount;
            emit Withdrawn(target, withdrawAmount);
        }

        if (rewardAmount > 0) {
            // TODO: distribute the reward
        }

        nonceRegistry[_nonce] = true;

        delete actionInQueue[target];
        delete signatures[target];
    }

    function pause() public onlyAdmin {
        super._pause();
    }

    function unpause() public onlyAdmin {
        super._unpause();
    }

    function setAdmin(address addr, bool flag) external onlyAdmin {
        require(addr != address(0), "WooPPV2: !admin");
        isAdmin[addr] = flag;
        emit AdminUpdated(addr, flag);
    }

    function setController(address _controller) external onlyAdmin {
        controller = _controller;
    }

    function setControllerChainId(uint16 _chainId) external onlyAdmin {
        controllerChainId = _chainId;
    }

    function emergency() external onlyAdmin {
        pause();

        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "StakingRewardsProxy: unable to send value, recipient may have reverted");
    }

    function emergencyWithdraw() external {
        _requirePaused();
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0;
        want.safeTransfer(msg.sender, balance);
        emit Withdrawn(msg.sender, balance);
    }

    function setGasAmounts(
        uint256 _proxyWithdraw,
        uint256 _proxyClaim,
        uint256 _controllerStake,
        uint256 _controllerWithdraw,
        uint256 _controllerClaim
    ) public onlyAdmin {
        if (_proxyWithdraw > 0) {
            gasAmounts.proxyWithdraw = _proxyWithdraw;
        }
        if (_proxyClaim > 0) {
            gasAmounts.proxyClaim = _proxyClaim;
        }
        if (_controllerStake > 0) {
            gasAmounts.controllerStake = _controllerStake;
        }
        if (_controllerWithdraw > 0) {
            gasAmounts.controllerWithdraw = _controllerWithdraw;
        }
        if (_controllerClaim > 0) {
            gasAmounts.controllerClaim = _controllerClaim;
        }
    }

    receive() external payable {}
}
