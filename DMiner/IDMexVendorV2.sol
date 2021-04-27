// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./IDMexVendorStorageV2.sol";

interface IDMexVendorV2 is IDMexVendorStorageV2 {
    
    event NewVendor(uint256 vendorid);
    event DisableVendor(uint256 vendorid);
    event NewProduct(uint256 prodid);
    event VendorWithdraw(address indexed user, uint256 prodid, uint256 amount);
    event VendorPledge(address indexed user, uint256 prodid, uint256 power, uint256 pledgeAmount, uint256 withdrawAmount);
    event UserRedemption(address indexed user, uint256 prodid, uint256 amount);
    event TransferProdRevenueReceiver(uint256 indexed prodid, address indexed user);
    event UpdateProduct(uint256 indexed prodid);
    event TransferVendorAdmin(uint256 indexed vendorid, address from, address to);
    event AddCapacity(uint256 indexed prodid, uint256 capacity);
    event SettlementAndTimeLock(uint256 indexed prodid, address indexed user, uint256 power, uint256 amount);
    
    function getVendor(uint256 _vendorid) external view returns(VendorInfo memory);
    
    function getProduct(uint256 _prodid) external view returns(ProductInfo memory);
    
    function settlementAndTimeLock(uint256 _prodid, address user, uint256 _power, uint256 _amount) external;
    
}
