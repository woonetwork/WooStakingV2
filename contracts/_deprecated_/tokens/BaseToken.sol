// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IBaseToken.sol";

contract BaseToken is Context, IERC20, IBaseToken {
    using SafeERC20 for IERC20;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public override totalSupply;
    uint256 public nonStakingSupply;

    address public gov;
    bool public inPrivateTransferMode;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(address => bool) public nonStakingAccounts;
    mapping(address => bool) public admins;
    mapping(address => bool) public isHandler;

    modifier onlyGov() {
        require(_msgSender() == gov, "BaseToken: forbidden");
        _;
    }

    modifier onlyAdmin() {
        require(admins[_msgSender()], "BaseToken: forbidden");
        _;
    }

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        gov = _msgSender();
        _mint(gov, _initialSupply);
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }

    function toggleAdmin(address _account) external onlyGov {
        admins[_account] = !admins[_account];
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external override onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external override onlyGov {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function addNonStakingAccount(address _account) external onlyAdmin {
        require(!nonStakingAccounts[_account], "BaseToken: _account already marked");
        nonStakingAccounts[_account] = true;
        nonStakingSupply += balances[_account];
    }

    function removeNonStakingAccount(address _account) external onlyAdmin {
        require(nonStakingAccounts[_account], "BaseToken: _account not marked");
        nonStakingAccounts[_account] = false;
        nonStakingSupply -= balances[_account];
    }

    function totalStaked() external view override returns (uint256) {
        return totalSupply - nonStakingSupply;
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function stakedBalance(address _account) external view override returns (uint256) {
        if (nonStakingAccounts[_account]) {
            return 0;
        }
        return balances[_account];
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(_msgSender(), _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(_msgSender(), _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
        address account = _msgSender();
        if (isHandler[account]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        uint256 nextAllowance = allowances[_sender][account] - _amount;
        _approve(_sender, account, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "BaseToken: mint to the zero address");

        totalSupply += _amount;
        balances[_account] += _amount;

        if (nonStakingAccounts[_account]) {
            nonStakingSupply += _amount;
        }

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "BaseToken: burn from the zero address");

        balances[_account] -= _amount;
        totalSupply -= _amount;

        if (nonStakingAccounts[_account]) {
            nonStakingSupply -= _amount;
        }

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "BaseToken: transfer from the zero address");
        require(_recipient != address(0), "BaseToken: transfer to the zero address");

        if (inPrivateTransferMode) {
            require(isHandler[_msgSender()], "BaseToken: msg.sender not whitelisted");
        }

        balances[_sender] -= _amount;
        balances[_recipient] += _amount;

        if (nonStakingAccounts[_sender]) {
            nonStakingSupply -= _amount;
        }
        if (nonStakingAccounts[_recipient]) {
            nonStakingSupply += _amount;
        }

        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "BaseToken: approve from the zero address");
        require(_spender != address(0), "BaseToken: approve to the zero address");
        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }
}
