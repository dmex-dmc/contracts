// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract MasterMiningProxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0x822A92BDB63C3ADec6dAc0Cdd2329041E5206A4F;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
