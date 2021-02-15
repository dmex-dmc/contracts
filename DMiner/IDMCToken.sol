// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/IERC20.sol";

interface IDMCToken is IERC20 {
    function mint(address _to, uint256 _amount) external;      
}
