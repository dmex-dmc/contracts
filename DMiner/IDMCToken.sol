// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./IERC20.sol";

interface IDMCToken is IERC20 {
    function mint(address _to, uint256 _amount) external;      
}
