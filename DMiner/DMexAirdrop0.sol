//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./IDMexAirdrop.sol";
import "./Vistor.sol";

contract DMexAirdrop0 is IDMexAirdrop,Vistor {
    
    uint32 private constant SOUVENIR_POWER = 2**32 - 1;
    
    uint256 public prodid;
    uint256 public endTime;
    
    mapping(address => bool) _userRecv;
    mapping(address => uint256) public _userPowers;
    
    constructor(uint256 _prodid, uint256 _endTime) public {
        prodid = _prodid;
        endTime = _endTime;
    }

    function addAirdrop(uint256 power, address[] calldata _users) external onlyGovernance {
        uint256 _power = power;
        if (power == 0) {
            _power = SOUVENIR_POWER;
        }
        for (uint256 i = 0; i < _users.length; i++) {
            if (_userPowers[_users[i]] > 0) {
                continue;
            }
            _userPowers[_users[i]] = _power;
        }
    }
    
    function recvAirdrop(address user) external onlyVistor override returns (uint256, uint256) {
        require(endTime >= block.timestamp && _userPowers[user] > 0, "can't recv airdrop");
        require(_userRecv[user] == false, "already recv airdrop");
        _userRecv[user] = true;
        uint256 _power = _userPowers[user];
        if (_power == SOUVENIR_POWER) {
            return (prodid, 0);
        } else {
            return (prodid, _power);
        }
    }

    function getAirdropEndTime() external override view returns (uint256) {
        return endTime;
    }

    function checkAirdrop(address user) external override view returns (bool, bool, uint256) {
        if (_userPowers[user] == 0) {
            return (false, false, 0);
        }
        uint256 _power = _userPowers[user];
        if (_power == SOUVENIR_POWER) {
            _power = 0;
        }
        return (endTime > block.timestamp, _userRecv[user], _power);
    }

}