//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract DMEXJointMiningStorage  {
    
    enum MiningPoolState {
        INIT,
        GROWING
    }
    
    struct MiningPool {
        uint256     createTime;
        uint256     effectPeriod;
        uint256     powers;
        uint256     price;
        address     admin;
    }
    
    struct GlobalInfo {
        address         ptoken;                    
        address         afil;
        address         dlp;                     //Principal Token
        address         dli;                     //Income Token
        uint256         dpPrice;
        uint256         userDeposits;
        uint256         userGainPrincipals;
        uint256         userGainBenefits;
        uint256         plateformBenefits;
        uint256         vendorGains;
        uint256         vendorReleasePrincipals;
        uint256         vendorReleaseBenefits;
        MiningPoolState state;
        bool            active;
    }
    
    struct VendorPool {
        GlobalInfo                  global;
        MiningPool[]                mpools;
        mapping(uint256 => bool) depositRecords;
    }
    
    struct BasePoolInfo {
        uint256     totalPrincipalAmount;
        uint256     totalBenefitAmount;
        uint256     principalLiquidAmount;
        uint256     benefitLiquidAmount;
        uint256     principalExchangeAmount;
        uint256     benefitExchangeAmount;
        uint256     dpPrice;
    }
    
    struct UserPool {
        uint256                     globalMask;
        mapping(address => uint256) userMask;
        mapping(address => uint256) userRecvs;
        mapping(address => uint256) userHolders;
    }
    
    mapping(bytes32 => UserPool) internal _userPools;
    mapping(bytes32 => VendorPool) internal _vendorPools;
}