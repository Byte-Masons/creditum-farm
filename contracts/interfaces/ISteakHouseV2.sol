// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISteakHouseV2  {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256[] RewardDebt; // Reward debt. See explanation below.
        uint256[] RemainingRewards; // Reward Tokens that weren't distributed for user per pool.
        //
        // We do some fancy math here. Basically, any point in time, the amount of STEAK
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.AccRewardsPerShare[i]) - user.RewardDebt[i]
        //
        // Whenever a user deposits or withdraws Staked tokens to a pool. Here's what happens:
        //   1. The pool's `AccRewardsPerShare` (and `lastRewardTime`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function getUserInfo(uint256 _pid, address _user)
        external
        view
        returns (UserInfo memory);
}