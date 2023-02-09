// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IBonusDistributor.sol";
import "../interfaces/IBonusTracker.sol";
import "../dependencies/Governable.sol";

contract SbWooRewardTracker is IERC20, ReentrancyGuard, IBonusTracker, Governable {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e30;
    uint256 public constant BASE_BOOSTING_MULTIPLIER = 1e6;
    uint8 public constant decimals = 18;

    string public name;
    string public symbol;

    BooleanStates public boolStates;

    address public manager;
    address public distributor;
    mapping(address => bool) public isHandler;
    mapping(address => bool) public isDepositToken;

    uint256 public override totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    uint256 public cumulativeRewardPerToken;
    mapping(address => uint256) public override stakedAmounts;
    mapping(address => uint256) public claimableReward;
    mapping(address => BoosterInfo) public boosterInfo;
    mapping(address => uint256) public previousCumulatedRewardPerToken;
    mapping(address => uint256) public override cumulativeRewards;
    mapping(address => mapping(address => uint256)) public override depositBalances;

    modifier isInExternalRewardingMode() {
        require(boolStates.inExternalRewardingMode, "Not in external rewarding mode");
        _;
    }

    modifier onlyManager() {
        require(_msgSender() == manager, "Only manager");
        _;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function initialize(address[] memory _depositTokens, address _distributor, address _manager) external onlyGov {
        require(!boolStates.isInitialized, "RewardTracker: already initialized");
        boolStates.isInitialized = true;

        for (uint256 i = 0; i < _depositTokens.length; i++) {
            address depositToken = _depositTokens[i];
            isDepositToken[depositToken] = true;
        }

        distributor = _distributor;
        manager = _manager;
    }

    function stake(address _depositToken, uint256 _amount) external override nonReentrant {
        if (boolStates.inPrivateStakingMode) {
            revert("RewardTracker: action not enabled");
        }
        _stake(_msgSender(), _msgSender(), _depositToken, _amount);
    }

    function stakeForAccount(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) external override nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _depositToken, _amount);
    }

    function unstake(address _depositToken, uint256 _amount) external override nonReentrant {
        if (boolStates.inPrivateStakingMode) {
            revert("RewardTracker: action not enabled");
        }
        _unstake(_msgSender(), _depositToken, _amount, _msgSender());
    }

    function unstakeForAccount(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) external override nonReentrant {
        _validateHandler();
        _unstake(_account, _depositToken, _amount, _receiver);
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(_msgSender(), _recipient, _amount);
        return true;
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

    function updateRewards() external override nonReentrant {
        _updateRewards(address(0));
    }

    function claim(address _receiver) external override nonReentrant returns (uint256) {
        if (boolStates.inPrivateClaimingMode) {
            revert("RewardTracker: action not enabled");
        }
        return _claim(_msgSender(), _receiver);
    }

    function claimForAccount(address _account, address _receiver) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(_account, _receiver);
    }

    function updateBoostingInfo(
        address account,
        uint256 amount,
        uint256 expiry
    ) external override isInExternalRewardingMode onlyManager {
        require(amount >= BASE_BOOSTING_MULTIPLIER, "RewardTracker: invalid value");
        require(expiry > block.timestamp, "RewardTracker: invalid value");
        boosterInfo[account].multiplier = amount;
        boosterInfo[account].expiry = expiry;

        emit BoostingEffectUpdated(amount, expiry);
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        require(!isDepositToken[_token], "RewardTracker: _token cannot be a depositToken");
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function setDepositToken(address _depositToken, bool _isDepositToken) external onlyGov {
        isDepositToken[_depositToken] = _isDepositToken;
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyGov {
        boolStates.inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setInPrivateStakingMode(bool _inPrivateStakingMode) external onlyGov {
        boolStates.inPrivateStakingMode = _inPrivateStakingMode;
    }

    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external onlyGov {
        boolStates.inPrivateClaimingMode = _inPrivateClaimingMode;
    }

    function setInExternalRewardingMode(bool _inExternalRewardingMode) external onlyGov {
        boolStates.inExternalRewardingMode = _inExternalRewardingMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function tokensPerInterval() external view override returns (uint256) {
        return IBonusDistributor(distributor).tokensPerInterval();
    }

    function claimable(address _account) public view override returns (uint256) {
        uint256 stakedAmount = stakedAmounts[_account];
        if (stakedAmount == 0) {
            return claimableReward[_account];
        }
        uint256 supply = totalSupply;
        uint256 pendingRewards = IBonusDistributor(distributor).pendingRewards() * PRECISION;
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken + pendingRewards / supply;

        uint256 newRewardAmount = (stakedAmount *
            (nextCumulativeRewardPerToken - previousCumulatedRewardPerToken[_account])) / PRECISION;

        return claimableReward[_account] + _boostedRewardAmount(_account, newRewardAmount);
    }

    function rewardToken() public view returns (address) {
        return IBonusDistributor(distributor).rewardToken();
    }

    function _claim(address _account, address _receiver) private returns (uint256) {
        _updateRewards(_account);

        uint256 tokenAmount = claimableReward[_account];
        claimableReward[_account] = 0;

        if (tokenAmount > 0) {
            IERC20(rewardToken()).safeTransfer(_receiver, tokenAmount);
            emit Claim(_account, tokenAmount);
        }

        return tokenAmount;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "RewardTracker: mint to the zero address");

        totalSupply += _amount;
        balances[_account] += _amount;

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "RewardTracker: burn from the zero address");

        balances[_account] -= _amount;
        totalSupply -= _amount;

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "RewardTracker: transfer from the zero address");
        require(_recipient != address(0), "RewardTracker: transfer to the zero address");

        if (boolStates.inPrivateTransferMode) {
            _validateHandler();
        }

        balances[_sender] -= _amount;
        balances[_recipient] += _amount;

        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "RewardTracker: approve from the zero address");
        require(_spender != address(0), "RewardTracker: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _validateHandler() private view {
        require(isHandler[_msgSender()], "RewardTracker: forbidden");
    }

    function _stake(address _fundingAccount, address _account, address _depositToken, uint256 _amount) private {
        require(_amount > 0, "RewardTracker: invalid _amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

        IERC20(_depositToken).safeTransferFrom(_fundingAccount, address(this), _amount);

        _updateRewards(_account);

        stakedAmounts[_account] += _amount;
        depositBalances[_account][_depositToken] += _amount;

        _mint(_account, _amount);
    }

    function _unstake(address _account, address _depositToken, uint256 _amount, address _receiver) private {
        require(_amount > 0, "RewardTracker: invalid _amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

        _updateRewards(_account);

        uint256 stakedAmount = stakedAmounts[_account];
        require(stakedAmounts[_account] >= _amount, "RewardTracker: _amount exceeds stakedAmount");

        stakedAmounts[_account] = stakedAmount - _amount;

        uint256 depositBalance = depositBalances[_account][_depositToken];
        require(depositBalance >= _amount, "RewardTracker: _amount exceeds depositBalance");
        depositBalances[_account][_depositToken] = depositBalance - _amount;

        _burn(_account, _amount);
        IERC20(_depositToken).safeTransfer(_receiver, _amount);
    }

    function _boostedRewardAmount(address _account, uint256 _amount) private view returns (uint256) {
        BoosterInfo memory _boosterInfo = boosterInfo[_account];
        if (_boosterInfo.expiry == 0 || _boosterInfo.expiry < block.timestamp) {
            return _amount;
        } else {
            return (_amount * _boosterInfo.multiplier) / BASE_BOOSTING_MULTIPLIER;
        }
    }

    function _updateRewards(address _account) private {
        uint256 blockReward = IBonusDistributor(distributor).distribute();

        uint256 supply = totalSupply;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        if (supply > 0 && blockReward > 0) {
            _cumulativeRewardPerToken += (blockReward * PRECISION) / supply;
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }

        // cumulativeRewardPerToken can only increase
        // so if cumulativeRewardPerToken is zero, it means there are no rewards yet
        if (_cumulativeRewardPerToken == 0) {
            return;
        }

        if (_account != address(0)) {
            uint256 stakedAmount = stakedAmounts[_account];
            uint256 accountReward = (stakedAmount *
                (_cumulativeRewardPerToken - previousCumulatedRewardPerToken[_account])) / PRECISION;
            uint256 boostedRewardAmount = _boostedRewardAmount(_account, accountReward);
            uint256 _claimableReward = claimableReward[_account] + boostedRewardAmount;

            uint256 additionalReward = boostedRewardAmount - accountReward;
            IBonusDistributor(distributor).boostReward(additionalReward);

            claimableReward[_account] = _claimableReward;
            previousCumulatedRewardPerToken[_account] = _cumulativeRewardPerToken;

            if (_claimableReward > 0 && stakedAmounts[_account] > 0) {
                uint256 nextCumulativeReward = cumulativeRewards[_account] + accountReward;

                cumulativeRewards[_account] = nextCumulativeReward;
            }
        }
    }
}
