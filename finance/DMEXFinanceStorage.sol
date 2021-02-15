//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract DMEXFinanceStorage  {
    
    enum ProdFinanceState {
        STOPPED,
        NORMAL
    }
    
    struct ProdFinance {
        uint256     famount;              //collection power
        uint256     lockDay;
        uint256     createTime;         //collection buy time
        address     recvAddr;         //End calculating earnings time
        uint256     totalGains;       //Received income
        uint256     previd;
        bool        active;
    }
    
    struct GlobalInfo {
        uint256     userDeposits;
        uint256     userGains;
        uint256     vendorDeposits;
        uint256     vendorGains;
        uint256     lastProdid;
        uint256     threshold;
    }
    
    struct TokenInfo {
        uint256                     totalSupply;
        uint256                     decimals;
        mapping(address => uint256) balances;
    }
    
    struct ABSPool {
        uint256     totalAmount;
        uint256     liquidAmount;
        uint256     exchangeAmount;
        uint256     tokenPrice;
    }
    
    struct ProdReleaseInfo {
        uint256     totalLocks;
        uint256     totalGains;
        uint256     lockDay;
        uint256     releaseDay;
        uint256     avlRecv;
        address     recvAddr;
    }
    
    mapping(uint256 => ProdFinance) internal _pfinances;
    TokenInfo internal _token;
    GlobalInfo internal _global;
}