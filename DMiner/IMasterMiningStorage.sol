//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "./IDMCToken.sol";

contract IMasterMiningStorage  {
    
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of DMCs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accDmcPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accDmcPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. DMCs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that DMCs distribution occurs.
        uint256 accDmcPerShare;   // Accumulated DMCs per share, times 1e12. See below.
        uint256 withdrawReward;   // Reward that has been withdrawn
        uint256 totalReward;      // Total reward of pool
        uint256 totalToken;       // Total amount of pledge
    }


    // Info of each pool.
    PoolInfo[] internal poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) internal userInfo;
    
}