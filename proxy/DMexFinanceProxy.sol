// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract DMexFinanceProxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0x2D638c361f306615Ba380E8f61Ce345f5c08Dba2;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
