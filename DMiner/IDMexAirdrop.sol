// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IDMexAirdrop {
    
    function recvAirdrop(address user) external returns (uint256, uint256);

    function getAirdropEndTime() external view returns (uint256);

    function checkAirdrop(address user) external view returns (bool, bool, uint256);

}
