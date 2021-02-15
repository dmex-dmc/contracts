// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./IDMexVendorStorage.sol";

interface IDMexVendor is IDMexVendorStorage {
    
    event NewVendor(uint256 vendorid);
    event DisableVendor(uint256 vendorid);
    event NewProduct(uint256 prodid);
    event VendorWithdraw(address indexed user, uint256 prodid, uint256 amount);
    event UserRedemption(address indexed user, uint256 prodid, uint256 amount);
    event TransferProdRevenueReceiver(uint256 indexed prodid, address indexed user);
    
    function getVendor(uint256 _vendorid) external view returns(VendorInfo memory);
    
    function getProduct(uint256 _prodid) external view returns(ProductInfo memory);
    
    function settlementAndTimeLock(uint256 _prodid, address user, uint256 _power, uint256 _amount) external;
    
}
