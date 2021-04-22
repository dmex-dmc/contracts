// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract DMexVendorV2Proxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0x3D98FB4Fdf1E83E6C05c4c49088c82b359BF4d89;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
