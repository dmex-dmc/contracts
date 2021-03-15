// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract DMEXJointMiningDmcProxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0xe44227975C95577Fc96BbCec21372116ef96E934;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
