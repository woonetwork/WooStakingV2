// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {TransferHelper} from "./util/TransferHelper.sol";

abstract contract BaseAdminOperation is Pausable, Ownable {
    event AdminUpdated(address indexed addr, bool flag);

    mapping(address => bool) public isAdmin;

    modifier onlyAdmin() {
        require(_msgSender() == owner() || isAdmin[_msgSender()], "BaseAdminOperation: !admin");
        _;
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    function setAdmin(address addr, bool flag) external onlyAdmin {
        isAdmin[addr] = flag;
        emit AdminUpdated(addr, flag);
    }

    function inCaseTokenGotStuck(address stuckToken) external onlyOwner {
        if (stuckToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            TransferHelper.safeTransferETH(_msgSender(), address(this).balance);
        } else {
            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, _msgSender(), amount);
        }
    }
}
