//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./DMEXFinanceStorage.sol";
import "./Vistor.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./TransferHelper.sol";

contract DMEXFinance is DMEXFinanceStorage, Vistor {
    
    using SafeMath for uint256;
    using Address for address;
    
    event UserDepositABS(address indexed user, uint256 amount, uint256 dtokens);
    event UserRedeemABS(address indexed user, uint256 amount, uint256 dtokens);
    event VendorDepositABS(address indexed user, uint256 indexed prodid, uint256 amount);
    event VendorWithdrawABS(address indexed user, uint256 indexed prodid, uint256 amount);
    
    bytes4 private constant ERC20_APPROVE_SELECTOR = bytes4(keccak256("approve(address,uint256)"));
    
    address private constant usdt = 0x93E3f452fBa08d9bB44D16F559AD9a9dF7153E2B;
    
    uint256 private constant DAYTIME = 86400;
    uint256 private constant PRICEPOINT = 10000;
    bool public _initialize;
    
    function initialize() public {
        require(_initialize == false, "already initialized");
        _initialize = true;
        _governance = msg.sender;
        _global.threshold = 50;
    }
    
    function getDTokenTotalSupply() public view returns(uint256) {
        return _token.totalSupply;
    }
    
    function getGlobalInfo() public view returns(GlobalInfo memory) {
        return _global;
    }
    
    function getProdFinanceInfo(uint256 _prodid) public view returns(ProdFinance memory) {
        return _pfinances[_prodid];
    }
    
    function activeABS(uint256 _prodid, uint256 _amount, uint256 _lockDay, address _admin) onlyVistor public {
        require(_pfinances[_prodid].active == false, "product already active!");
        require(_lockDay > 0, "error release params!");
        
        _pfinances[_prodid].famount = _amount;
        _pfinances[_prodid].lockDay = _lockDay;
        _pfinances[_prodid].createTime = block.timestamp;
        _pfinances[_prodid].recvAddr = _admin;
        _pfinances[_prodid].active = true;
        if (_global.lastProdid > 0) {
            _pfinances[_prodid].previd = _global.lastProdid;
        }
        _global.lastProdid = _prodid;
        _global.vendorDeposits += _amount;
        emit VendorDepositABS(_admin, _prodid, _amount);
    }
    
    function userDeposit(uint256 _amount) public {
        TransferHelper.safeTransferFrom(usdt, msg.sender, address(this), _amount);
        uint256 exchangeAmount = _amount.mul(PRICEPOINT).div(_getCurrentDtokenPrice());
        _token.balances[msg.sender] = _token.balances[msg.sender].add(exchangeAmount);
        _token.totalSupply = _token.totalSupply.add(exchangeAmount);
        
        _global.userDeposits = _global.userDeposits.add(_amount);
        emit UserDepositABS(msg.sender, _amount, exchangeAmount);
    }
    
    function userRedeem() public {
        uint256 burnAmount = _token.balances[msg.sender];
        uint256 redeemAmount = burnAmount.mul(_getCurrentDtokenPrice()).div(PRICEPOINT);
        _token.balances[msg.sender] = 0;
        _token.totalSupply = _token.totalSupply.sub(burnAmount);
        
        _global.userGains = _global.userGains.add(redeemAmount);
        TransferHelper.safeTransferFrom(usdt, address(this),  msg.sender, redeemAmount);
        emit UserRedeemABS(msg.sender, redeemAmount, burnAmount);
    }
    
    function vendorWithdraw(uint256 _prodid) external {
        uint256 amount = _calcProdCanRecvs(_prodid);
        if (amount > 0) {
            TransferHelper.safeTransferFrom(usdt, address(this), msg.sender, amount);
            _global.vendorGains += amount;
            _pfinances[_prodid].totalGains += amount;
            emit VendorWithdrawABS(msg.sender, _prodid, amount);
        }
    }
    
    function getABSPoolInfo() external view returns(ABSPool memory) {
        uint256 totalRecv = _global.userGains.add(_global.vendorGains);
        return ABSPool({
            totalAmount: _global.userDeposits.add(_global.vendorDeposits),
            liquidAmount: _getLiquidAmout(),
            exchangeAmount: totalRecv,
            tokenPrice: _getCurrentDtokenPrice()
        });
    }
    
    function getProdReleaseInfo(uint256 _prodid) external view returns(ProdReleaseInfo memory) {
        uint256 diffDay;
        {
            uint256 startTime = _pfinances[_prodid].createTime.div(DAYTIME).mul(DAYTIME);
            uint256 curDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
    		diffDay = curDayTime.sub(startTime).div(DAYTIME);
    		if (diffDay > _pfinances[_prodid].lockDay) {
    		    diffDay = _pfinances[_prodid].lockDay;
    		}
        }
        return ProdReleaseInfo({
            totalLocks: _pfinances[_prodid].famount,
            totalGains: _pfinances[_prodid].totalGains,
            lockDay: _pfinances[_prodid].lockDay,
            releaseDay: diffDay,
            avlRecv: _calcProdCanRecvs(_prodid),
            recvAddr: _pfinances[_prodid].recvAddr
        });
    }
    
    function balanceOf(address owner) external view returns(uint256) {
        return _token.balances[owner];
    }
    
    function _getCurrentDtokenPrice() private view returns(uint256) {
        if (_token.totalSupply <= 0 || _getLiquidAmout() == 0) {
            return PRICEPOINT;
        }
        return _getLiquidAmout().mul(PRICEPOINT).div(_token.totalSupply);
    }
    
    function _calcProdCanRecvs(uint256 _prodid) private view returns(uint256) {
        if (!_pfinances[_prodid].active) {
            return 0;
        }
        uint256 prodRecvAmount;
        {
            uint256 prodMaxRecv;
            if (_checkProdHasRecvOver(_prodid)) {
                prodMaxRecv = _pfinances[_prodid].famount.mul(85).div(100).sub(_pfinances[_prodid].totalGains);
            } else {
                prodMaxRecv = _pfinances[_prodid].famount.mul(85).mul(_global.threshold).div(10000).sub(_pfinances[_prodid].totalGains);
            }
            uint256 startTime = _pfinances[_prodid].createTime.div(DAYTIME).mul(DAYTIME);
            uint256 curDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
    		uint256 diffDay = curDayTime.sub(startTime).div(DAYTIME);
    		if (diffDay > _pfinances[_prodid].lockDay) {
    		    diffDay = _pfinances[_prodid].lockDay;
    		}
    		uint256 liquidAmount = _getLiquidAmout();
    		
    		if (liquidAmount > prodMaxRecv) {
    		    prodRecvAmount = prodMaxRecv;
    		} else {
    		    prodRecvAmount = liquidAmount;
    		}
        }
		return prodRecvAmount;
    }
    
    function _getReleaseAmount() private view returns(uint256) {
        uint256 nextid = _global.lastProdid;
        uint256 curDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        
        uint256 totalRelease;
        
        while (nextid > 0) {
            uint256 startTime = _pfinances[nextid].createTime.div(DAYTIME).mul(DAYTIME);
    		uint256 diffDay = curDayTime.sub(startTime).div(DAYTIME);
    		if (diffDay > _pfinances[nextid].lockDay) {
    		    diffDay = _pfinances[nextid].lockDay;
    		}
    		totalRelease += _pfinances[nextid].famount.mul(diffDay).div(_pfinances[nextid].lockDay).mul(15).div(100);
    		nextid = _pfinances[nextid].previd;
        }
        return totalRelease;
    }
    
    function _getLiquidAmout() private view returns(uint256) {
        return _getReleaseAmount().add(_global.userDeposits).sub(_global.userGains).sub(_global.vendorGains);
    }
    
    function _checkProdHasRecvOver(uint256 _prodid) private view returns(bool) {
        uint256 previd = _pfinances[_prodid].previd;
        if (previd == 0) {
            return true;
        }
        return _pfinances[previd].totalGains >= _pfinances[previd].famount.mul(85).div(100);
    }
    
}