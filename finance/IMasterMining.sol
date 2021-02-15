// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


interface IMasterMining {
    function getPledgeAmount(address _lpToken, address _user) external view returns (uint256 amount); 
}
