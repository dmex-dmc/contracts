// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./IERC20.sol";

interface IDMEXToken is IERC20 {
    
    function mint(uint256 _amount) external;
    
    function burn(uint256 _amount) external;
    
}
