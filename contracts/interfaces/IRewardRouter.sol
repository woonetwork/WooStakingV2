// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IRewardRouter {
    event StakeToken(address account, address token, uint256 amount);
    event UnstakeToken(address account, address token, uint256 amount);

    function initialize(
        address _usdc,
        address _token,
        address _esToken,
        address _bnToken,
        address _stakedTokenTracker,
        address _bonusTokenTracker,
        address _feeTokenTracker
    ) external;

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external;

    function batchStakeTokenForAccount(address[] memory _accounts, uint256[] memory _amounts) external;

    function stakeTokenForAccount(address _account, uint256 _amount) external;

    function stakeToken(uint256 _amount) external;

    function unstakeToken(uint256 _amount) external;

    function claim() external;

    function claimFees() external;

    function compound() external;

    function compoundForAccount(address _account) external;

    function handleRewards(bool _shouldStakeMultiplierPoints, bool _shouldClaimUSDC) external;

    function batchCompoundForAccounts(address[] memory _accounts) external;
}
