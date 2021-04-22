// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./TransparentUpgradeableProxy.sol";

contract IFilDMinerV2Proxy is TransparentUpgradeableProxy {
    
    address private constant initProxy = 0x6A233B4f1b45325fb0Fed4Ba914e121BaB22fbfA;
    
    constructor() public TransparentUpgradeableProxy(initProxy, msg.sender, "") {
    }
    
}
