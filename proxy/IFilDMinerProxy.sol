// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract IFilDMinerProxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0x2F58617A6efdbd16eB8a78151b9f5a2cac4d9924;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
