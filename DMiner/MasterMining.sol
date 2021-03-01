//SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;



import "./SafeERC20.sol";
import "./IMasterMiningStorage.sol";
import "./Governance.sol";


contract MasterMining is IMasterMiningStorage, Governance {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    // The DMC TOKEN!
    IDMCToken public dmc;

    // Block number when bonus DMC period ends.
    uint256 public bonusEndBlock;
    // DMC tokens created per block.
    uint256 public dmcPerBlock;
    // DMC tokens created first 3 days per block.
    uint256 public dmcFirstDaysPerBlock;
    // Bonus muliplier for early dmc makers.
    uint256 public constant BONUS_MULTIPLIER = 10;
    
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when DMC mining starts.
    uint256 public startBlock;
    
    bool public _initialize;
    
    uint256 public constant first_3_days = 3 * 24 * 60 * 20;
    

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Add(address indexed lp, uint256 indexed pid, uint256 allocPoint);
    
    function initialize(
            IDMCToken _dmc,
            uint256 _dmcFirst3DaysPerBlock,
            uint256 _dmcPerBlock,
            uint256 _startBlock,
            uint256 _bonusEndBlock
        ) public {
        require(_initialize == false, "already initialized");
        _initialize = true;
        _governance = msg.sender;
        dmc = _dmc;
        dmcPerBlock = _dmcPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        dmcFirstDaysPerBlock = _dmcFirst3DaysPerBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyGovernance {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        uint256 pid = poolInfo.length;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accDmcPerShare: 0,
            totalToken: 0,
            totalReward: 0,
            withdrawReward: 0
        }));
        emit Add(address(_lpToken), pid, _allocPoint);
    }

    // Update the given pool's DMC allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyGovernance {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }
    
        
    //fix update bug
    function updateData(uint256 _dmcPerBlock, uint256 _bonusEndBlock) public onlyGovernance {
        dmcPerBlock = _dmcPerBlock;
        bonusEndBlock = _bonusEndBlock;
    }

    // Get mining total reward
    function getTotalReward(uint256 blockNum) public view returns (uint256) {
        if(blockNum <= startBlock) {
            return 0;
        }
        
        if(blockNum > bonusEndBlock) {
            blockNum = bonusEndBlock;
        }
        
        if(blockNum < startBlock + first_3_days) {
            return dmcFirstDaysPerBlock * (blockNum - startBlock);
        }
        
        uint256 first_3_days_total = dmcFirstDaysPerBlock * first_3_days;
        uint256 halveCycle = 180 * 24 * 60 * 20;        // 3 seconds one block, about 180 days, 5184000 blocks;
        uint256 halveTimes = (blockNum - startBlock - first_3_days) / halveCycle;
        uint256 totalReward = first_3_days_total;
        uint256 currDmcPerBlock = dmcPerBlock;
        if( halveTimes > 0 ) {
            for(uint256 i=1; i<=halveTimes; ++i) {
                totalReward += currDmcPerBlock * halveCycle;
                currDmcPerBlock = currDmcPerBlock >> 1; 
            }
            totalReward += (blockNum - startBlock - first_3_days - halveCycle * halveTimes) * currDmcPerBlock;
            return totalReward;
        }
        else {
            return first_3_days_total + dmcPerBlock * (blockNum - startBlock - first_3_days);
        }
    }
    
    
    //halve block reward every six month
    function getCurrentBlockReward() public view returns (uint256) {
        if(block.number <= startBlock || block.number > bonusEndBlock) {
            return 0;
        }
        
        if(block.number <= startBlock + first_3_days) {
            return dmcFirstDaysPerBlock;
        }
        
        uint256 halveCycle = 180 * 24 * 60 * 20;        // 3 seconds one block, about 180 days, 5184000 blocks;
        uint256 halveTimes = (block.number - startBlock - first_3_days) / halveCycle;
        return dmcPerBlock >> halveTimes;         

    }
    
    
    function getDifferBlockReward(uint256 _from, uint256 _to) public view returns (uint256) {
        return getTotalReward(_to) - getTotalReward(_from);   
    }
    

    // View function to see pending DMCs on frontend.
    function pendingDmc(uint256 _pid, address _user) public  view returns (uint256 reward, uint256 blockNum, uint256 lastRewardBlock) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDmcPerShare = pool.accDmcPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 dmcReward = getDifferBlockReward(pool.lastRewardBlock, block.number).mul(pool.allocPoint).div(totalAllocPoint);
          
            accDmcPerShare = accDmcPerShare.add(dmcReward.mul(1e12).div(lpSupply));
        }
        return (user.amount.mul(accDmcPerShare).div(1e12).sub(user.rewardDebt), block.number, pool.lastRewardBlock);
    }

    //Calculate a specific block height reward
    function pendingDmcBlock(uint256 _pid, address _user, uint256 blockNum) public  view returns (uint256 reward, uint256 lastRewardBlock) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDmcPerShare = pool.accDmcPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (blockNum > pool.lastRewardBlock && lpSupply != 0) {
            uint256 dmcReward = getDifferBlockReward(pool.lastRewardBlock, blockNum).mul(pool.allocPoint).div(totalAllocPoint);
          
            accDmcPerShare = accDmcPerShare.add(dmcReward.mul(1e12).div(lpSupply));
        }
        return (user.amount.mul(accDmcPerShare).div(1e12).sub(user.rewardDebt),  pool.lastRewardBlock);
    }
    
    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 dmcReward = getDifferBlockReward(pool.lastRewardBlock, block.number).mul(pool.allocPoint).div(totalAllocPoint);
        dmc.mint(address(this), dmcReward);
        pool.totalReward = pool.totalReward.add(dmcReward);
        pool.accDmcPerShare = pool.accDmcPerShare.add(dmcReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to Mining Pool for DMC allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accDmcPerShare).div(1e12).sub(user.rewardDebt);
            pool.withdrawReward = pool.withdrawReward.add(pending);
            safeDmcTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.totalToken = pool.totalToken.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accDmcPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Mining Pool.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accDmcPerShare).div(1e12).sub(user.rewardDebt);
        pool.withdrawReward = pool.withdrawReward.add(pending);
        safeDmcTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        pool.totalToken = pool.totalToken.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accDmcPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    // Withdraw  all LP tokens from Mining Pool.
    function withdrawAll(uint256 _pid) public {
        UserInfo storage user = userInfo[_pid][msg.sender];
        withdraw(_pid, user.amount);
    }
    
    // Get user information
    function getUserInfo(uint256 _pid, address _user) external  view returns (uint256 amount, 
        uint256 reward, 
        address lpToken) {
        
        PoolInfo storage pool = poolInfo[_pid];    
        UserInfo storage user = userInfo[_pid][_user];
        (reward,, ) = pendingDmc(_pid, _user);

        return (user.amount, reward, address(pool.lpToken));
    }
    
    // Get pool information
    function getPoolInfo(uint256 _pid) external  view returns (
        uint256 allocPoint,
        uint256 totalToken, 
        uint256 totalReward, 
        address lpToken) {
        
        PoolInfo storage pool = poolInfo[_pid];
        
        uint256 poolReward = pool.totalReward;
        if(pool.lastRewardBlock < block.number) {
            uint256 dmcReward = getDifferBlockReward(pool.lastRewardBlock, block.number).mul(pool.allocPoint).div(totalAllocPoint);
            poolReward = poolReward.add(dmcReward);
        }
        poolReward = poolReward.sub(pool.withdrawReward);

        return (pool.allocPoint, pool.totalToken, poolReward, address(pool.lpToken));
    }
    
    // Get user information by block number
    function getUserInfoByBlockNumber(uint256 _pid, address _user, uint256 _blockNum) external  view returns (uint256 amount, 
        uint256 reward, 
        uint256 totalToken, 
        uint256 totalReward, 
        address lpToken) {
            
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        
        (reward, ) = pendingDmcBlock(_pid, _user, _blockNum);
        
        uint256 poolReward = pool.totalReward;
        if(pool.lastRewardBlock < _blockNum) {
            uint256 dmcReward = getDifferBlockReward(pool.lastRewardBlock, _blockNum).mul(pool.allocPoint).div(totalAllocPoint);
            poolReward = poolReward.add(dmcReward);
        }
        poolReward = poolReward.sub(pool.withdrawReward);

        return (user.amount, reward, pool.totalToken, poolReward, address(pool.lpToken));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        pool.totalToken = pool.totalToken.sub(user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe dmc transfer function, just in case if rounding error causes pool to not have enough DMC.
    function safeDmcTransfer(address _to, uint256 _amount) internal {
        uint256 dmcBal = dmc.balanceOf(address(this));
        if (_amount > dmcBal) {
            dmc.transfer(_to, dmcBal);
        } else {
            dmc.transfer(_to, _amount);
        }
    }
    
    //Get the total amount of user pledge 
    function getPledgeAmount(address _lpToken, address _user) public view returns (uint256 amount) {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            if(address(pool.lpToken) == _lpToken) {
                UserInfo storage user = userInfo[pid][_user];
                amount = amount.add(user.amount);
            }
        }
        return amount;
    }
    
    //Get the total alloc point of some pools
    function sumPoolAllocPoint(uint256[] memory _pids) public view returns (uint256 _subAllocPoint, uint256 _totalAllocPoint){
        uint256 length = _pids.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[_pids[pid]];
            _subAllocPoint = _subAllocPoint.add(pool.allocPoint);
        }
        
        return (_subAllocPoint, totalAllocPoint);
    }

}
