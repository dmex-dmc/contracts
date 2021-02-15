//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IDMexVendorStorage  {
    
    enum VendorState {
        DISABLED,
        NORMAL
    }
    
    enum ProdState {
        STOPPED,
        NORMAL
    }
    
    struct VendorInfo {
        address     admin;              //vendor admin
        address     recvAddr;           //address vendor recv usdt
        bytes32     vendorName;         //vendor name
        uint256     disableTime;
        VendorState state;
    }
    
    struct ProductInfo {
        uint256     vendorid;           //vendor id
        uint256     prodType;           //1.common prod(Available for purchase) 2.airdrop(Not available for purchase)
        uint256     pubPower;           //Project released power capacity
        uint256     soldPower;          //Project sold power capacity
        uint256     power;              //power of each shard(Unit is GB)
        uint256     effectPeriod;       //Total collection time(Unit is day)
        uint256     activePeriod;       //How soon after the collection is purchased(Unit is day)
        uint256     startTime;          //purchase time must after startTime, no limit if value is 0
        uint256     endTime;            //purchase time must before endTime, no limit if value is 0
        uint256     price;              //each power price(USDT)
        ProdState   state;
    }
    
    struct ProdTimeLock {
        uint256                     totalLocks;
        uint256                     totalGains;
        mapping(address => uint256) userPowers;
        address                     owner;
    }
    
}