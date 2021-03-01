//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./DMEXJointMiningStorage.sol";
import "./Vistor.sol";
import "./SafeMath.sol";
import "./Address.sol";
import "./DFinanceToken.sol";
import "./TransferHelper.sol";
import "./IMasterMining.sol";

contract DMEXJointMining is DMEXJointMiningStorage,Vistor {
    
    using SafeMath for uint256;
    using Address for address;
    
    event UserDepositMPool(address indexed user, bytes32 indexed pid, uint256 amount, uint256 dlpTokens, uint256 dliTokens);
    event UserRedeemMPool(address indexed user, bytes32 indexed pid, uint256 principalAmount, uint256 dlpTokens, uint256 dliTokens);
    event UserIncomeMPool(address indexed user, bytes32 indexed pid, uint256 incomeAmount);
    
    event VendorCreateMPool(uint256 indexed vendorid, address indexed payToken, bytes32 pid);
    event VendorExpandMPool(address indexed user, bytes32 indexed pid, uint256 amount);
    event VendorWithdrawMPool(address indexed user, bytes32 indexed pid, uint256 amount);
    event VendorDepositMPool(bytes32 indexed pid, uint256 fundAmount, uint256 principalAmount, uint256 incomeAmount, uint256 incomeValut);
    event UpdateWithdrawFees(uint256 feeRate, uint256 plateformRate);
    
    address private constant fundAddr = 0xb40eA8ca2DCcae0864e7Ff4dfb1bfdd4D990b5a9;
    address private constant ifil = 0xae3a768f9aB104c69A7CD6041fE16fFa235d1810;
    
    uint256 private constant DAYTIME = 86400;
    uint256 private constant GLOBAL_DECIMAL = 10 ** 18;
    uint256 public WITHDRAW_FEE_RATE;
    uint256 public PLATEFORM_FEE_RATE;
    bool public _initialize;
    
    function initialize() public {
        require(_initialize == false, "already initialized");
        _initialize = true;
        _governance = msg.sender;
        WITHDRAW_FEE_RATE = 3;
        PLATEFORM_FEE_RATE = 2;
    }
    
    function getGlobalInfo(bytes32 _pid) public view returns(GlobalInfo memory) {
        return _vendorPools[_pid].global;
    }
    
    function updateWithdrawFees(uint256 _feeRate, uint256 _plateformRate) onlyGovernance public {
        require(_feeRate.add(_plateformRate) < 10000, "Error Fees");
        WITHDRAW_FEE_RATE = _feeRate;
        PLATEFORM_FEE_RATE = _plateformRate;
        emit UpdateWithdrawFees(_feeRate, _plateformRate);
    }
    
    function createMiningPool(uint256 _vendorid, address _payToken) onlyVistor public {
        bytes32 pid = keccak256(abi.encodePacked(_vendorid, _payToken));
        require(_vendorPools[pid].global.active == false, "MiningPool Exists!");
        _vendorPools[pid].global.ptoken = _payToken;
        _vendorPools[pid].global.active = true;
        _vendorPools[pid].global.afil = _createToken("AFIL TOKEN", "AFIL", DFinanceToken(_payToken).decimals(), true);
        _vendorPools[pid].global.dlp = _createToken("DLP TOKEN", "DLP", DFinanceToken(_payToken).decimals(), false);
        _vendorPools[pid].global.dli = _createToken("DLI TOKEN", "DLI", DFinanceToken(ifil).decimals(), false);
        _vendorPools[pid].global.dpPrice = GLOBAL_DECIMAL; //init dp price 1
        emit VendorCreateMPool(_vendorid, _payToken, pid);
    }
    
    function expandMiningPool(bytes32 _pid, uint256 _power, uint256 _price, uint256 _effectPeriod, address _admin) onlyVistor public {
        require(_vendorPools[_pid].global.active, "pool not exists");
        require((_effectPeriod > 0 && _power >0 && _price > 0), "error release params!");
        
        MiningPool memory _mpool = MiningPool({
            createTime:     block.timestamp,
            effectPeriod:   _effectPeriod,
            powers:         _power,
            price:          _price,
            admin:          _admin
        });
        
        _vendorPools[_pid].mpools.push(_mpool);
        uint256 mintAmount = _power.mul(_price);
        DFinanceToken(_vendorPools[_pid].global.afil).mint(_admin, mintAmount);
        emit VendorExpandMPool(msg.sender, _pid, mintAmount);
    }
    
    function vendorDepositBenefits(bytes32 _pid, uint256 _fundAmount, uint256 _principalAmount, uint256 _incomeAmount, uint256 _incomeValut) onlyVistor public {
        uint256 dayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        require(_vendorPools[_pid].depositRecords[dayTime] == false, "today has been deposit benefits");
        require(_fundAmount > 0 && _principalAmount > 0 && _incomeAmount > 0 && _incomeValut > 0, "Error Release!");
        
        TransferHelper.safeTransferFrom(_vendorPools[_pid].global.ptoken, msg.sender, address(this), _principalAmount);
        TransferHelper.safeTransferFrom(ifil, msg.sender, address(this), _incomeAmount);
        TransferHelper.safeTransferFrom(ifil, msg.sender, fundAddr, _fundAmount);
        _vendorPools[_pid].depositRecords[dayTime] = true;
        _vendorPools[_pid].global.vendorReleasePrincipals += _principalAmount;
        _vendorPools[_pid].global.vendorReleaseBenefits += _incomeAmount;
        
        _updateBenefitPool(_pid, _incomeAmount, _incomeValut);
        
        emit VendorDepositMPool(_pid, _fundAmount, _principalAmount, _incomeAmount, _incomeValut);
    }
    
    function userDeposit(bytes32 _pid, uint256 _amount) public {
        require(_vendorPools[_pid].global.active, "pool not exists");
        require(_amount > 0, "invalid deposit value");
        TransferHelper.safeTransferFrom(_vendorPools[_pid].global.ptoken, msg.sender, address(this), _amount);
        
        DFinanceToken dlp = DFinanceToken(_vendorPools[_pid].global.dlp);
        DFinanceToken dli = DFinanceToken(_vendorPools[_pid].global.dli);
        
        GlobalInfo storage _global = _vendorPools[_pid].global;
        UserPool storage _userPool = _userPools[_pid];
        
        uint256 exchangeAmount = _accuracyConversion(_amount, _global.dlp, _global.dli).mul(GLOBAL_DECIMAL).div(_global.dpPrice);
        dlp.mint(msg.sender, _amount);
        dli.mint(msg.sender, exchangeAmount);
        
        _userPool.userRecvs[msg.sender] += _userPool.globalMask.sub(_userPool.userMask[msg.sender]).mul(_userPool.userHolders[msg.sender]).div(GLOBAL_DECIMAL);
        _userPool.userHolders[msg.sender] = _userPool.userHolders[msg.sender].add(exchangeAmount);
        _userPool.userMask[msg.sender] = _userPool.globalMask;
        
        _global.userDeposits = _global.userDeposits.add(_amount);
        if (_global.state == MiningPoolState.INIT) {
            uint256 _THRESHOLD = _vendorPools[_pid].mpools[0].powers.mul(_vendorPools[_pid].mpools[0].price);
            if (_global.userDeposits >= _THRESHOLD) {
                _global.state = MiningPoolState.GROWING;
            }
        }
        
        emit UserDepositMPool(msg.sender, _pid, _amount, _amount, exchangeAmount);
    }
    
    function _userRedeemCommon(IMasterMining masterMining, bytes32 _pid, uint256 _amount) internal {
        require(_vendorPools[_pid].global.active, "pool not exists");
        require(_amount > 0, "invalid redeem value");
        DFinanceToken dlp = DFinanceToken(_vendorPools[_pid].global.dlp);
        DFinanceToken dli = DFinanceToken(_vendorPools[_pid].global.dli);
        
        GlobalInfo storage _global = _vendorPools[_pid].global;
        
        require(_global.state == MiningPoolState.GROWING, "Can't redeem util growth period start");
        uint256 balance = dlp.balanceOf(msg.sender);
        if(address(masterMining) != address(0x0)) {
            balance = balance.add(masterMining.getPledgeAmount(address(dlp), msg.sender));
        }
        require(balance >= _amount, "not enough DLP");
        
        userIncome(_pid);
        
        uint256 _dliTokens = dli.balanceOf(msg.sender).mul(_amount).div(balance);
        
        dlp.burn(msg.sender, _amount);
        dli.burn(msg.sender, _dliTokens);
        UserPool storage _userPool = _userPools[_pid];
        _userPool.userHolders[msg.sender] = _userPool.userHolders[msg.sender].sub(_dliTokens);
        
        _global.userGainPrincipals = _global.userGainPrincipals.add(_amount);
        
        uint256 plateformAmount = _amount.mul(PLATEFORM_FEE_RATE).div(10000);
        uint256 remainAmount = _amount.sub(plateformAmount);
        TransferHelper.safeTransfer(_vendorPools[_pid].global.ptoken, fundAddr, plateformAmount);
        TransferHelper.safeTransfer(_vendorPools[_pid].global.ptoken, msg.sender, remainAmount);
        emit UserRedeemMPool(msg.sender, _pid, remainAmount, _amount, _dliTokens);
    }
    
    function userRedeem(bytes32 _pid, uint256 _amount) public {
        _userRedeemCommon(IMasterMining(0x0), _pid, _amount);
    }
    
    function userRedeemV2(IMasterMining masterMining, bytes32 _pid, uint256 _amount) public {
        _userRedeemCommon(masterMining, _pid, _amount);
    }
    
    function userIncome(bytes32 _pid) public {
        require(_vendorPools[_pid].global.active, "pool not exists");
        
        uint256 userBenefits = getUserIncome(_pid);
        
        if (userBenefits > 0) {
            GlobalInfo storage _global = _vendorPools[_pid].global;
            UserPool storage _userPool = _userPools[_pid];
            
            uint256 feeAmount = userBenefits.mul(WITHDRAW_FEE_RATE).div(10000);
            uint256 incomeAmount = userBenefits.sub(feeAmount);
            
            _userPool.userMask[msg.sender] = _userPool.globalMask;
            _userPool.userRecvs[msg.sender] = 0;
            _updateBenefitPool(_pid, feeAmount, 0);
            
            _global.userGainBenefits = _global.userGainBenefits.add(incomeAmount);
            
            TransferHelper.safeTransfer(ifil, msg.sender, incomeAmount);
            
            emit UserIncomeMPool(msg.sender, _pid, incomeAmount);
        }
    }
    
    function getUserIncome(bytes32 _pid) public view returns(uint256) {
        UserPool storage _userPool = _userPools[_pid];
        return _userPool.globalMask.sub(_userPool.userMask[msg.sender]).mul(_userPool.userHolders[msg.sender]).div(GLOBAL_DECIMAL).add(_userPool.userRecvs[msg.sender]);
    }
    
    function vendorWithdrawAll(bytes32 _pid) public {
        require(_vendorPools[_pid].global.active, "pool not exists");
        address afil = _vendorPools[_pid].global.afil;
        uint256 afilAmount = DFinanceToken(afil).balanceOf(msg.sender);
        vendorWithdraw(_pid,afilAmount);
    }
    
    function vendorWithdraw(bytes32 _pid, uint256 _amount) public {
        require(_vendorPools[_pid].global.active, "pool not exists");
        uint256 canRecvAmount = _calcVendorCanRecvs(_pid);
        address afil = _vendorPools[_pid].global.afil;
        uint256 afilAmount = DFinanceToken(afil).balanceOf(msg.sender);
        require(_amount <= afilAmount, "Insufficient Balance");
         
        if (canRecvAmount > 0 && _amount > 0) {
            uint256 withdrawAmount;
            if (canRecvAmount >= _amount) {
                withdrawAmount = _amount;
            } else {
                withdrawAmount = canRecvAmount;
            }
            DFinanceToken(afil).burn(msg.sender, withdrawAmount);
            
            TransferHelper.safeTransfer(_vendorPools[_pid].global.ptoken, msg.sender, withdrawAmount);
            
            _vendorPools[_pid].global.vendorGains += withdrawAmount;
            emit VendorWithdrawMPool(msg.sender, _pid, withdrawAmount);
        }
    }
    
    function getMiningPoolInfo(bytes32 _pid) external view returns(BasePoolInfo memory) {
        GlobalInfo memory _global = _vendorPools[_pid].global;
        return BasePoolInfo({
            totalPrincipalAmount: _global.userDeposits.add(_global.vendorReleasePrincipals),
            totalBenefitAmount: _global.vendorReleaseBenefits,
            principalLiquidAmount: _getPrincipalLiquid(_pid),
            benefitLiquidAmount: _getBenefitLiquid(_pid),
            principalExchangeAmount: _global.vendorGains.add(_global.userGainPrincipals),
            benefitExchangeAmount: _global.userGainBenefits,
            dpPrice: _global.dpPrice
        });
    }
    
    function vendorCanRecvs(bytes32 _pid) public view returns(uint256) {
        return _calcVendorCanRecvs(_pid);
    }
    
    function _updateBenefitPool(bytes32 _pid, uint256 _amount, uint256 _amountValut) private {
        uint256 dliTotalSupply = DFinanceToken(_vendorPools[_pid].global.dli).totalSupply();
        if (dliTotalSupply > 0) {
            UserPool storage _userPool = _userPools[_pid];
            _userPool.globalMask += _amount.mul(GLOBAL_DECIMAL).div(dliTotalSupply);
            
            if (_amountValut > 0) {
                GlobalInfo storage _global = _vendorPools[_pid].global;
                _global.dpPrice = _global.dpPrice.mul(dliTotalSupply).add(_amountValut.mul(GLOBAL_DECIMAL)).div(dliTotalSupply);
            }
        }
    }
    
    function _calcVendorCanRecvs(bytes32 _pid) private view returns(uint256) {
        if (!_vendorPools[_pid].global.active) {
            return 0;
        }
        
        uint256 maxRecvAmount = _getMaxRecvAmount(_pid);
        if (maxRecvAmount <= _vendorPools[_pid].global.vendorGains) {
            return 0;
        }
        uint256 recvAmount = maxRecvAmount.sub(_vendorPools[_pid].global.vendorGains);
        uint256 liquidAmount = _getPrincipalLiquid(_pid);
        
        if (liquidAmount > recvAmount) {
            return recvAmount;
        } else {
            return liquidAmount;
        }
    }
    
    function _getMaxRecvAmount(bytes32 _pid) private view returns(uint256) {
        MiningPool[] memory _mpools = _vendorPools[_pid].mpools;
        uint256 maxRecvAmount;
        {
            for (uint256 i = 0; i < _mpools.length; i++) {
                maxRecvAmount += _mpools[i].price.mul(_mpools[i].powers);
            }
        }
        return maxRecvAmount;
    }
    
    function _getPrincipalLiquid(bytes32 _pid) private view returns(uint256) {
        GlobalInfo memory _global = _vendorPools[_pid].global;
        return _global.userDeposits.add(_global.vendorReleasePrincipals).sub(_global.userGainPrincipals).sub(_global.vendorGains);
    }
    
    function _getBenefitLiquid(bytes32 _pid) private view returns(uint256) {
        GlobalInfo memory _global = _vendorPools[_pid].global;
        return _global.vendorReleaseBenefits.sub(_global.userGainBenefits).sub(_global.plateformBenefits);
    }
    
    function _createToken(string memory _symbol, string memory _name, uint8 _decimals, bool _isTransfer) private returns(address) {
        bytes memory deploymentData = abi.encodePacked(
            type(DFinanceToken).creationCode,
            abi.encode(_symbol, _name, _decimals, _isTransfer)
        );
        bytes32 salt = keccak256(abi.encodePacked(_symbol, _name, _decimals, _isTransfer, block.timestamp));
        address _token;
        assembly {
            _token := create2(
                0x0, add(0x20, deploymentData), mload(deploymentData), salt
            )
        }
		require(_token != address(0), "Create2: Failed on create token");
		return _token;
    }
    
    function _accuracyConversion(uint256 _amount, address _source, address _dest) private view returns(uint256) {
        if (_source == _dest) {
            return _amount;
        }
        return _amount.mul(_getTokenDecimalValue(_dest)).div(_getTokenDecimalValue(_source));
    }
    
    function _getTokenDecimalValue(address _token) private view returns(uint256) {
        return 10 ** uint256(DFinanceToken(_token).decimals());
    }
}
