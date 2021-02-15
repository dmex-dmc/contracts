//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract IFilDMinerStorage  {
    
    struct IFilNFT {
        uint256     prodid;             //product id
        uint256     power;              //collection power
        uint256     createTime;         //collection buy time
        uint256     activeTime;         //Start calculating earnings time
        uint256     expireTime;         //End calculating earnings time
        uint256     gainBenefits;       //Received income
    }
    
    struct BenefitPool {
        uint256     effectPower;        //effective NFT power
        uint256     fixedMineAmount;    //Fixed release part
        uint256     linearMineAmount;   //Linear release part
    }
    
    struct UserInfo {
        bytes32     uid;
        address     inviter;
        address[]   invitees;
        uint256     ugrade;             //0.common user 1.light node 2.main node
        uint256     gainBenefits;
    }
    
    struct BackUser {
        bytes32     uid;
        address     inviter;
        uint256     inviteeNum;
        uint256     tokenNum;
        uint256     ugrade;
        uint256     effectPower;
        uint256     received;
        uint256     available;
        uint256     unreleased;
    }
    
    mapping(uint256 => IFilNFT) internal _ifilNfts;
    mapping(uint256 => uint256[]) internal _prodNfts;
    mapping(uint256 => mapping(uint256 => BenefitPool)) internal _beftPools;
    mapping(address => UserInfo) internal _users;
    mapping(bytes32 => address) internal _uids;
    
}