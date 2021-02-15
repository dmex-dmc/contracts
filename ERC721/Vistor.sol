//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./Governance.sol";

contract Vistor is Governance {

    mapping(address => bool) private visitors;
    
    event UpdateVistor(address indexed visitor, bool allow);

    modifier onlyVistor {
        require(visitors[msg.sender], "not allow");
        _;
    }

    function setVistor(address _addr, bool allow) onlyGovernance external {
        visitors[_addr] = allow;
        emit UpdateVistor(_addr, allow);
    }
    
    function allow(address _addr) external view returns(bool) {
        return visitors[_addr];
    }
    
}
