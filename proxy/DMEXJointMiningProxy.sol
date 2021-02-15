// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract DMEXJointMiningProxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0xC07Dfa04B3F1560c89a108b75B51b557F0F914Cc;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
