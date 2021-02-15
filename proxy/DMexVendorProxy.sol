// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract DMexVendorProxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0x4bbC7Fe0bD1F74dB65FaBfcAb68f3520238B3396;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
