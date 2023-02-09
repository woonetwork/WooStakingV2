// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IRewardRouter.sol";
import "./interfaces/IRewardTracker.sol";
import "./interfaces/IMintable.sol";
import "./dependencies/Governable.sol";

contract RewardRouter is IRewardRouter, ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public usdc;

    address public token;
    address public esToken;
    address public bnToken;
    address public stakedTokenTracker;
    address public bonusTokenTracker;
    address public feeTokenTracker;

    mapping(address => address) public pendingReceivers;

    receive() external payable {
        revert("Router: no ETH");
    }

    function initialize(
        address _usdc,
        address _token,
        address _esToken,
        address _bnToken,
        address _stakedTokenTracker,
        address _bonusTokenTracker,
        address _feeTokenTracker
    ) external onlyGov {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;

        usdc = _usdc;

        token = _token;
        esToken = _esToken;
        bnToken = _bnToken;

        stakedTokenTracker = _stakedTokenTracker;
        bonusTokenTracker = _bonusTokenTracker;
        feeTokenTracker = _feeTokenTracker;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function batchStakeTokenForAccount(
        address[] memory _accounts,
        uint256[] memory _amounts
    ) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeToken(_msgSender(), _accounts[i], token, _amounts[i]);
        }
    }

    function stakeTokenForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
        _stakeToken(_msgSender(), _account, token, _amount);
    }

    function stakeToken(uint256 _amount) external nonReentrant {
        _stakeToken(_msgSender(), _msgSender(), token, _amount);
    }

    function unstakeToken(uint256 _amount) external nonReentrant {
        _unstakeToken(_msgSender(), token, _amount, true);
    }

    function unstakeTokenForAccount(address _user, uint256 _amount) external nonReentrant {
        _unstakeToken(_user, token, _amount, true);
    }

    function instantUnstakeToken(uint256 _amount) external nonReentrant {
        _unstakeToken(_msgSender(), token, _amount, false);
    }

    function claim() external nonReentrant {
        address account = _msgSender();

        IRewardTracker(feeTokenTracker).claimForAccount(account, account);
        IRewardTracker(stakedTokenTracker).claimForAccount(account, account);
    }

    function claimFees() external nonReentrant {
        address account = _msgSender();

        IRewardTracker(feeTokenTracker).claimForAccount(account, account);
    }

    function compound() external nonReentrant {
        _compound(_msgSender());
    }

    function compoundForAccount(address _account) external nonReentrant onlyGov {
        _compound(_account);
    }

    function handleRewards(bool _shouldStakeMultiplierPoints, bool _shouldClaimUSDC) external nonReentrant {
        address account = _msgSender();

        if (_shouldStakeMultiplierPoints) {
            uint256 bnTokenAmount = IRewardTracker(bonusTokenTracker).claimForAccount(account, account);

            if (bnTokenAmount > 0) {
                IRewardTracker(feeTokenTracker).stakeForAccount(account, account, bnToken, bnTokenAmount);
            }
        }

        if (_shouldClaimUSDC) {
            IRewardTracker(feeTokenTracker).claimForAccount(account, account);
        }
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyGov {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function _compound(address _account) private {
        _compoundToken(_account);
    }

    function _compoundToken(address _account) private {
        uint256 bnTokenAmount = IRewardTracker(bonusTokenTracker).claimForAccount(_account, _account);
        if (bnTokenAmount > 0) {
            IRewardTracker(feeTokenTracker).stakeForAccount(_account, _account, bnToken, bnTokenAmount);
        }
    }

    function _stakeToken(address _fundingAccount, address _account, address _token, uint256 _amount) private {
        require(_amount > 0, "RewardRouter: invalid _amount");

        // esWoo
        IRewardTracker(stakedTokenTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);

        // bnWoo
        IRewardTracker(bonusTokenTracker).stakeForAccount(_account, _account, stakedTokenTracker, _amount);

        // WETH/USDC
        IRewardTracker(feeTokenTracker).stakeForAccount(_account, _account, bonusTokenTracker, _amount);

        emit StakeToken(_account, _token, _amount);
    }

    function _unstakeToken(address _account, address _token, uint256 _amount, bool _shouldReduceBnToken) private {
        require(_amount > 0, "RewardRouter: invalid _amount");
        uint256 balance = IRewardTracker(stakedTokenTracker).stakedAmounts(_account);

        IRewardTracker(feeTokenTracker).unstakeForAccount(_account, bonusTokenTracker, _amount, _account);
        IRewardTracker(bonusTokenTracker).unstakeForAccount(_account, stakedTokenTracker, _amount, _account);
        IRewardTracker(stakedTokenTracker).unstakeForAccount(_account, _token, _amount, _account);

        if (_shouldReduceBnToken) {
            uint256 bnTokenAmount = IRewardTracker(bonusTokenTracker).claimForAccount(_account, _account);
            if (bnTokenAmount > 0) {
                IRewardTracker(feeTokenTracker).stakeForAccount(_account, _account, bnToken, bnTokenAmount);
            }

            uint256 stakedBnToken = IRewardTracker(feeTokenTracker).depositBalances(_account, bnToken);
            if (stakedBnToken > 0) {
                uint256 reductionAmount = (stakedBnToken * _amount) / balance;
                IRewardTracker(feeTokenTracker).unstakeForAccount(_account, bnToken, reductionAmount, _account);
                IMintable(bnToken).burn(_account, reductionAmount);
            }
        }

        emit UnstakeToken(_account, _token, _amount);
    }
}
