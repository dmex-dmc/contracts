//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./IDMexVendorV2.sol";
import "./Vistor.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract DMexVendorV2 is IDMexVendorV2,Vistor {
    
    using SafeMath for uint256;
    using Address for address;
    
    mapping(uint256 => VendorInfo) internal _vendors;
    mapping(uint256 => ProductInfo) internal _prods;
    mapping(uint256 => FundTimeLock) internal _fundTimeLocks;
    uint256[] internal _pledgeProjs;
    
    bytes4 private constant ERC20_TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private constant ERC20_TRANSFERFROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
    
    //address private constant usdt = 0x93E3f452fBa08d9bB44D16F559AD9a9dF7153E2B;
    //address private constant dmc = 0x50A3d9cbB5615Ed650fFa48DA36FfA5cF82fcd79;
    //address private constant fundAddr = 0x79c2608714F03a463BDE490C3BABBEF70ff29B6d;
    
    uint256 private constant DAYTIME = 86400;
    uint256 public _globalVendorid = 100;
    uint256 public _globalProdid = 100;
    bool public _initialize;
    
    function initialize() public {
        require(_initialize == false, "already initialized");
        _initialize = true;
        _governance = msg.sender;
    }
    
    function addVendor(bytes calldata _vendorData) external onlyGovernance {
        VendorInfo memory _vendor = abi.decode(_vendorData, (VendorInfo));
        _globalVendorid++;
        _vendors[_globalVendorid] = _vendor;
        emit NewVendor(_globalVendorid);
    }
    
    function addProduct(bytes calldata _prodData) external {
        ProductInfo memory _product = abi.decode(_prodData, (ProductInfo));
        require(_vendors[_product.vendorid].admin == msg.sender, "not admin");
        require(_vendors[_product.vendorid].state == VendorState.NORMAL, "Vendor is disabled");
        require(_product.endTime > block.timestamp, "Must be greater than current time");
        
        _globalProdid++;
        _prods[_globalProdid] = _product;
        _fundTimeLocks[_globalProdid].owner = _vendors[_product.vendorid].recvAddr;
        emit NewProduct(_globalProdid);
    }
    
    function updateProduct(uint256 _prodid, bytes calldata _prodData) external onlyGovernance {
        ProductInfo memory _product = abi.decode(_prodData, (ProductInfo));
        _prods[_prodid].pubPower = _product.pubPower;
        _prods[_prodid].endTime = _product.endTime;
        _prods[_prodid].price = _product.price;
        _prods[_prodid].effectPeriod = _product.effectPeriod;
        _prods[_prodid].activePeriod = _product.activePeriod;
        _prods[_prodid].pledgeToken = _product.pledgeToken;
        _prods[_prodid].payToken = _product.payToken;
        _prods[_prodid].benefitsToken = _product.benefitsToken;
        _prods[_prodid].pledgeAmount = _product.pledgeAmount;
        _prods[_prodid].pledgeDmcAmount = _product.pledgeDmcAmount;
        _prods[_prodid].maxBuyPower = _product.maxBuyPower;
        emit UpdateProduct(_prodid);
    }
    
    function transferVendorAdmin(uint256 _vendorid, address _to) external {
        require(_vendors[_vendorid].admin == msg.sender, "only admin");
        require(_vendors[_vendorid].state == VendorState.NORMAL, "Vendor is disabled");
        
        _vendors[_vendorid].admin = _to;
        emit TransferVendorAdmin(_vendorid, msg.sender, _to);
    }
    
    function transferProdRevenueReceiver(uint256 _prodid, address _to) external {
        require(_fundTimeLocks[_prodid].owner == msg.sender, "only timelock owner");
        require(_vendors[_prods[_prodid].vendorid].state == VendorState.NORMAL, "Vendor is disabled");
        
        _fundTimeLocks[_prodid].owner = _to;
        emit TransferProdRevenueReceiver(_prodid, _to);
    }
    
    function disableVendor(uint256 _vendorid) external onlyGovernance {
        _vendors[_vendorid].state = VendorState.DISABLED;
        _vendors[_vendorid].disableTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        emit DisableVendor(_vendorid);
    }
    
    function getVendor(uint256 _vendorid) external override view returns(VendorInfo memory) {
        return _vendors[_vendorid];
    }
    
    function getProduct(uint256 _prodid) external override view returns(ProductInfo memory) {
        return _prods[_prodid];
    }
    
    function initVendor(uint256 _vendorid) external onlyGovernance{
        _vendors[_vendorid].disableTime = 0;
        _vendors[_vendorid].state = VendorState.NORMAL;
    }
    
    function addCapacity(uint256 _prodid, uint256 capacity) public {
        require(block.timestamp <= _prods[_prodid].endTime, "Sale time has ended");
        VendorInfo memory _vendor = _vendors[_prods[_prodid].vendorid];
        require(msg.sender == _vendor.admin, "only product admin");
        _prods[_prodid].pubPower = _prods[_prodid].pubPower.add(capacity);
        emit AddCapacity(_prodid, capacity);
    }
    
    function settlementAndTimeLock(uint256 _prodid, address user, uint256 _power, uint256 _amount) external override onlyVistor {
        require(_prods[_prodid].soldPower.add(_power) <= _prods[_prodid].pubPower, "Item sold out");
        require(_prods[_prodid].state == ProdState.NORMAL, "Product has been stopped!");
        require(block.timestamp <= _prods[_prodid].endTime, "Sale time has ended");
        
        _fundTimeLocks[_prodid].totalLocksFil += _amount;
        _prods[_prodid].soldPower += _power;
        emit SettlementAndTimeLock(_prodid, user, _power, _amount);
    }

    
    function vendorPledge(uint256 _prodid, uint256 power, uint256 pledgeAmount) external {
        require(_fundTimeLocks[_prodid].owner == msg.sender, "only timelock owner");
        require(_prods[_prodid].soldPower <= _prods[_prodid].pubPower, "All the pledge has been completed");
        
        uint256 remainPower = _prods[_prodid].soldPower.sub(_fundTimeLocks[_prodid].gainPower);
        require(remainPower > 0, "remain power is zero");
        if(power > remainPower) {
            power = remainPower;
        }
        uint256 needDmcAmount = power.mul(_prods[_prodid].pledgeDmcAmount);
        require(pledgeAmount >= needDmcAmount, "Insufficient recharge");
        
        _fundTimeLocks[_prodid].gainPower = _fundTimeLocks[_prodid].gainPower.add(power);
        
        uint256 totalAmount = _fundTimeLocks[_prodid].totalLocksFil.mul(power).div(remainPower);
        _fundTimeLocks[_prodid].totalLocksFil = _fundTimeLocks[_prodid].totalLocksFil.sub(totalAmount);
        
        _fundTimeLocks[_prodid].locks.push(TimeLock({
            startTime: block.timestamp,
            lockPeriod: _prods[_prodid].effectPeriod,
            totalLocksDmc: needDmcAmount,
            totalGains: 0
        }));
        
        _fundTimeLocks[_prodid].totalLocksDmc = _fundTimeLocks[_prodid].totalLocksDmc.add(needDmcAmount);
        
        _pledgeProjs.push(_prodid);
        
        _safeTransferFrom(_prods[_prodid].pledgeToken, msg.sender, address(this), needDmcAmount);
        _safeTransfer(_prods[_prodid].payToken, msg.sender, totalAmount);
        
        emit VendorPledge(msg.sender, _prodid, power, needDmcAmount, totalAmount);
    }
    
    
    function vendorWithdraw(uint256 _prodid) external {
        require(_fundTimeLocks[_prodid].owner == msg.sender, "only timelock owner");
        uint256 curDay = block.timestamp.div(DAYTIME).mul(DAYTIME);
        
        FundTimeLock storage _fundTimeLock = _fundTimeLocks[_prodid];
        TimeLock[]  storage locks = _fundTimeLock.locks;
        
        uint256 amount = 0;
        for (uint256 i = 0; i < locks.length; i++) {
            TimeLock storage lock = locks[i];
            uint256 startTime = lock.startTime.div(DAYTIME).mul(DAYTIME);
            uint256 diffDay = curDay.sub(startTime).div(DAYTIME);
            if (diffDay > lock.lockPeriod) {
                amount = amount.add(lock.totalLocksDmc.sub(lock.totalGains));
                lock.totalGains = lock.totalLocksDmc;
            } else {
                amount = amount.add(lock.totalLocksDmc.mul(diffDay).div(lock.lockPeriod).sub(lock.totalGains));
                lock.totalGains = lock.totalLocksDmc.mul(diffDay).div(lock.lockPeriod);
            }
        }
        
        if (amount > 0) {
            _fundTimeLock.totalGainDmc = _fundTimeLock.totalGainDmc.add(amount);
            _safeTransfer(_prods[_prodid].pledgeToken, msg.sender, amount);
            emit VendorWithdraw(msg.sender, _prodid, amount);
        }
    }
    
    function available(uint256 _prodid) external view returns(uint256, uint256, uint256, address) {
        uint256 pubAmount = _prods[_prodid].pubPower.mul(_prods[_prodid].price).mul(95).div(100);
        uint256 gainAmount = _fundTimeLocks[_prodid].gainPower.mul(_prods[_prodid].price).mul(95).div(100);
        
        return (pubAmount, gainAmount, pubAmount - gainAmount, _fundTimeLocks[_prodid].owner);
    }
    
    
    function getPledgeDmcInfo(uint256 _prodid) external view returns(uint256, uint256, uint256, address) {
        uint256 willGainAmount = _calcTotalRecv(_prodid);
        return (_fundTimeLocks[_prodid].totalLocksDmc, _fundTimeLocks[_prodid].totalGainDmc, willGainAmount, _fundTimeLocks[_prodid].owner);
    }
    
    function getPowerInfo(uint256 _prodid) external view returns(uint256, uint256, uint256) {
        return (_prods[_prodid].pubPower, _prods[_prodid].soldPower, _fundTimeLocks[_prodid].gainPower);
    }
    
    function _calcTotalRecv(uint256 _prodid) internal view returns(uint256) {
        uint256 dayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        VendorInfo memory _vendor = _vendors[_prods[_prodid].vendorid];
        if (_vendor.state == VendorState.DISABLED && dayTime > _vendor.disableTime) {
            dayTime = _vendor.disableTime;
        }
        
        FundTimeLock memory _fundTimeLock = _fundTimeLocks[_prodid];
        TimeLock[]  memory locks = _fundTimeLock.locks;
        
        uint256 amount = 0;
        for (uint256 i = 0; i < locks.length; i++) {
            TimeLock memory lock = locks[i];
            uint256 startTime = lock.startTime.div(DAYTIME).mul(DAYTIME);
            uint256 diffDay = dayTime.sub(startTime).div(DAYTIME);
            if (diffDay > lock.lockPeriod) {
                amount = amount.add(lock.totalLocksDmc.sub(lock.totalGains));
            } else {
                amount = amount.add(lock.totalLocksDmc.mul(diffDay).div(lock.lockPeriod).sub(lock.totalGains));
            }
        }
        
        return amount;
    }
    
    function _safeTransfer(address _token, address _to, uint256 _amount) private {
        bytes memory returnData = _token.functionCall(abi.encodeWithSelector(
            ERC20_TRANSFER_SELECTOR,
            _to,
            _amount
        ), "ERC20: transfer call failed");
        
        if (returnData.length > 0) { // Return data is optional
            require(abi.decode(returnData, (bool)), "ERC20: transfer did not succeed");
        }
    }
    
    function _safeTransferFrom(address _token, address _from, address _to, uint256 _amount) private {
        bytes memory returnData = _token.functionCall(abi.encodeWithSelector(
            ERC20_TRANSFERFROM_SELECTOR,
            _from,
            _to,
            _amount
        ), "ERC20: transferFrom call failed");
        
        if (returnData.length > 0) { // Return data is optional
            require(abi.decode(returnData, (bool)), "ERC20: transferFrom did not succeed");
        }
    }
}