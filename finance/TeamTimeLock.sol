//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Governance.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract TeamTimeLock is Governance {
    
    using SafeMath for uint256;
    using Address for address;
    
    event TeamLockRecv(address indexed user, uint256 amount);
    event AddTeam(address indexed user, uint256 amount);
    event StartTimeLock(uint256 startBlock, address dmcToken);
    
    uint256 public startBlock;
    address public dmcToken;
    uint256 public totalAmount;
    mapping(address => uint256) teamHolder;
    mapping(address => uint256) teamRecvs;
    
    uint256 public constant lockPeriod = 36;
    uint256 public constant totalLocks = 10000000 * 10 ** 18;
    bytes4 private constant ERC20_TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    
	function startTimeLock(address _dmcToken) onlyGovernance external {
	    require(dmcToken == address(0), "Error State");
	    dmcToken = _dmcToken;
	    startBlock = block.number;
	    emit StartTimeLock(startBlock, dmcToken);
	}
	
	function addTeam(address user, uint256 amount) onlyGovernance external {
	    require(amount > 0, "invalid value");
	    require(teamHolder[user] == 0, "already exists!");
	    require(totalAmount.add(amount) <= totalLocks, "exceed limit");
	    teamHolder[user] = amount;
	    totalAmount += amount;
	    emit AddTeam(user, amount);
	}
	
	function teamRecvLock() public {
	    uint256 totalReleases = _teamTotalUnlocks(msg.sender);
	    if (totalReleases > teamRecvs[msg.sender]) {
	        uint256 userRecvs = totalReleases.sub(teamRecvs[msg.sender]);
	        _safeTransfer(dmcToken, msg.sender, userRecvs);
	        teamRecvs[msg.sender] = totalReleases;
	        emit TeamLockRecv(msg.sender, userRecvs);
	    }
	}
	
	function calcTeamRecvLock() public view returns(uint256) {
	    return _teamTotalUnlocks(msg.sender).sub(teamRecvs[msg.sender]);
	}
	
	function calcUserTeamRecvLock(address user) public view returns(uint256) {
	    return _teamTotalUnlocks(user).sub(teamRecvs[user]);
	}
	
	function userTeamRecvs(address user) public view returns(uint256) {
	    return teamRecvs[user];
	}
	
	function userTeamHolder(address user) public view returns(uint256) {
	    return teamHolder[user];
	}
	
	function _teamTotalUnlocks(address user) private view returns(uint256) {
	    uint256 amount = teamHolder[user];
	    uint256 diffBlock = block.number - startBlock;
	    uint256 _period = diffBlock.div(30 * 28800);
	    if (_period > lockPeriod) {
	        return amount;
	    } else {
	        return amount.mul(_period).div(lockPeriod);
	    }
	}
	
    function _safeTransfer(address _token, address _to, uint256 _amount) private {
        bytes memory returnData = _token.functionCall(abi.encodeWithSelector(
            ERC20_TRANSFER_SELECTOR,
            _to,
            _amount
        ), "ERC20: transfer call failed");
        
        if (returnData.length > 0) { // Return data is optional
            require(abi.decode(returnData, (bool)), "ERC20: transfer did not succeed");
        }
    }
    
}