// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

import "./interfaces/IRewardRouter.sol";
import "./util/TransferHelper.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

contract WooStakingController is NonblockingLzApp, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint8 public constant ACTION_STAKE = 1;
    uint8 public constant ACTION_UNSTAKE = 2;
    uint8 public constant ACTION_COMPOUND = 3;

    IRewardRouter public rewardRouter;

    mapping(address => uint256) public balances;
    mapping(address => bool) public isAdmin;

    event StakeOnController(address indexed user, uint256 amount);
    event WithdrawOnController(address indexed user, uint256 amount);
    event CompoundOnController(address indexed user);
    event AdminUpdated(address indexed addr, bool flag);

    modifier onlyAdmin() {
        require(msg.sender == owner() || isAdmin[msg.sender], "WooStakingController: !admin");
        _;
    }

    constructor(address _endpoint, address _rewardRouter) NonblockingLzApp(_endpoint) {
        rewardRouter = IRewardRouter(_rewardRouter);
    }

    // --------------------- LZ Receive Message Functions --------------------- //

    function _nonblockingLzReceive(
        uint16 /*_srcChainId*/,
        bytes memory /*_srcAddress*/,
        uint64 /*_nonce*/,
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
        rewardRouter.stakeTokenForAccount(_user, _amount);
        balances[_user] += _amount;
        emit StakeOnController(_user, _amount);
    }

    function _withdraw(address _user, uint256 _amount) private {
        balances[_user] -= _amount;
        rewardRouter.unstakeTokenForAccount(_user, _amount);
        emit WithdrawOnController(_user, _amount);
    }

    function _compound(address _user) private {
        rewardRouter.compoundForAccount(_user);
        emit CompoundOnController(_user);
    }

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

    function setRewardRouter(address _router) external onlyAdmin {
        rewardRouter = IRewardRouter(_router);
    }

    function syncBalance(address _user, uint256 _balance) external onlyAdmin {
        // TODO: handle the balance and reward update
    }

    function inCaseTokenGotStuck(address stuckToken) external onlyOwner {
        if (stuckToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        } else {
            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }

    receive() external payable {}
}
