//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Governance.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract PETimeLock is Governance {
    
    using SafeMath for uint256;
    using Address for address;
    
    event PELockRecv(address indexed user, uint256 amount);
    event AddPE(address indexed user, uint256 amount);
    event StartTimeLock(uint256 startBlock, address dmcToken);
    
    uint256 public startBlock;
    address public dmcToken;
    uint256 public totalAmount;
    mapping(address => uint256) peHolder;
    mapping(address => uint256) peRecvs;
    
    uint256 public constant lockPeriod = 4;
    uint256 public constant totalLocks = 20000000 * 10 ** 18;
    bytes4 private constant ERC20_TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    
	function startTimeLock(address _dmcToken) onlyGovernance external {
	    require(dmcToken == address(0), "Error State");
	    dmcToken = _dmcToken;
	    startBlock = block.number;
	    emit StartTimeLock(startBlock, dmcToken);
	}
	
	function addPE(address user, uint256 amount) onlyGovernance external {
	    require(amount > 0, "invalid value");
	    require(peHolder[user] == 0, "already exists!");
	    require(totalAmount.add(amount) <= totalLocks, "exceed limit");
	    peHolder[user] = amount;
	    totalAmount += amount;
	    emit AddPE(user, amount);
	}
	
	function peRecvLock() public {
	    uint256 totalReleases = _peTotalUnlocks(msg.sender);
	    if (totalReleases > peRecvs[msg.sender]) {
	        uint256 userRecvs = totalReleases.sub(peRecvs[msg.sender]);
	        _safeTransfer(dmcToken, msg.sender, userRecvs);
	        peRecvs[msg.sender] = totalReleases;
	        emit PELockRecv(msg.sender, userRecvs);
	    }
	}
	
	function calcPERecvLock() public view returns(uint256) {
	    return _peTotalUnlocks(msg.sender).sub(peRecvs[msg.sender]);
	}
	
	function calcUserPERecvLock(address user) public view returns(uint256) {
	    return _peTotalUnlocks(user).sub(peRecvs[user]);
	}
	
	function userPERecvs(address user) public view returns(uint256) {
	    return peRecvs[user];
	}
	
	function userPEHolder(address user) public view returns(uint256) {
	    return peHolder[user];
	}
	
	
	function _peTotalUnlocks(address user) private view returns(uint256) {
	    uint256 amount = peHolder[user];
	    uint256 diffBlock = block.number - startBlock;
	    uint256 _period = diffBlock.div(90 * 28800);
	    if (_period >= lockPeriod) {
	        return amount;
	    } else {
	        return amount.mul(1 + _period).div(5);
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