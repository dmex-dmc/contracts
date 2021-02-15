//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./IDMexVendor.sol";
import "./Vistor.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract DMexVendor is IDMexVendor,Vistor {
    
    using SafeMath for uint256;
    using Address for address;
    
    mapping(uint256 => VendorInfo) internal _vendors;
    mapping(uint256 => ProductInfo) internal _prods;
    mapping(uint256 => ProdTimeLock) _prodTimeLocks;
    mapping(uint256 => mapping(address => bool)) _userRedemptions;
    
    bytes4 private constant ERC20_TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    address private constant usdt = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;
    
    uint256 private constant DAYTIME = 86400;
    uint256 public _globalVendorid = 0;
    uint256 public _globalProdid = 0;
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
        _prodTimeLocks[_globalProdid].owner = _vendors[_product.vendorid].recvAddr;
        emit NewProduct(_globalProdid);
    }
    
    function updateProduct(uint256 _prodid, bytes calldata _prodData) external onlyGovernance {
        ProductInfo memory _product = abi.decode(_prodData, (ProductInfo));
        _prods[_prodid].pubPower = _product.pubPower;
        _prods[_prodid].endTime = _product.endTime;
        _prods[_prodid].price = _product.price;
        _prods[_prodid].effectPeriod = _product.effectPeriod;
        _prods[_prodid].activePeriod = _product.activePeriod;
    }
    
    function transferVendorAdmin(uint256 _vendorid, address _to) external {
        require(_vendors[_vendorid].admin == msg.sender, "only admin");
        require(_vendors[_vendorid].state == VendorState.NORMAL, "Vendor is disabled");
        
        _vendors[_vendorid].admin = _to;
    }
    
    function transferProdRevenueReceiver(uint256 _prodid, address _to) external {
        require(_prodTimeLocks[_prodid].owner == msg.sender, "only timelock owner");
        require(_vendors[_prods[_prodid].vendorid].state == VendorState.NORMAL, "Vendor is disabled");
        
        _prodTimeLocks[_prodid].owner = _to;
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
    }
    
    function settlementAndTimeLock(uint256 _prodid, address user, uint256 _power, uint256 _amount) external override onlyVistor {
        require(_prods[_prodid].soldPower.add(_power) <= _prods[_prodid].pubPower, "Item sold out");
        require(_prods[_prodid].state == ProdState.NORMAL, "Product has been stopped!");
        require(block.timestamp <= _prods[_prodid].endTime, "Sale time has ended");
        
        _prodTimeLocks[_prodid].totalLocks += _amount;
        _prodTimeLocks[_prodid].userPowers[user] += _power;
        _prods[_prodid].soldPower += _power;
    }
    
    function withdraw(uint256 _prodid) external {
        require(_prodTimeLocks[_prodid].owner == msg.sender, "only timelock owner");
        uint256 totalAmount = _calcTotalRecv(_prodid);
        if (totalAmount > _prodTimeLocks[_prodid].totalGains) {
            uint256 ugains = totalAmount.sub(_prodTimeLocks[_prodid].totalGains);
            _prodTimeLocks[_prodid].totalGains = totalAmount;
            
            bytes memory returnData = usdt.functionCall(abi.encodeWithSelector(
                ERC20_TRANSFER_SELECTOR,
                msg.sender,
                ugains
            ), "DMexVendor: ERC20 transfer call failed");
            
            if (returnData.length > 0) { // Return data is optional
                require(abi.decode(returnData, (bool)), "DMexVendor: ERC20 transfer did not succeed");
            }
            
            emit VendorWithdraw(msg.sender, _prodid, ugains);
        }
    }
    
    function userRedemption(uint256 _prodid) external {
        VendorInfo memory _vendor = _vendors[_prods[_prodid].vendorid];
        require(_prods[_prodid].prodType == 1, "Only salable product");
        require(_vendor.state == VendorState.DISABLED, "redemption not now");
        require(_prodTimeLocks[_prodid].userPowers[msg.sender] > 0, "not allow redemption");
        require(_userRedemptions[_prodid][msg.sender] == false, "you has been redemptioned");
        uint256 totalRedemptionAmount = _prodTimeLocks[_prodid].totalLocks.sub(_calcTotalRecv(_prodid));
        uint256 userRedemptionAmount = totalRedemptionAmount.mul(_prodTimeLocks[_prodid].userPowers[msg.sender]).div(_prods[_prodid].soldPower);
        
        bytes memory returnData = usdt.functionCall(abi.encodeWithSelector(
            ERC20_TRANSFER_SELECTOR,
            msg.sender,
            userRedemptionAmount
        ), "DMexVendor: ERC20 transfer call failed");
        
        if (returnData.length > 0) { // Return data is optional
            require(abi.decode(returnData, (bool)), "DMexVendor: ERC20 transfer did not succeed");
        }
        
        _userRedemptions[_prodid][msg.sender] = true;
        emit UserRedemption(msg.sender, _prodid, userRedemptionAmount);
    }
    
    
    function available(uint256 _prodid) external view returns(uint256, uint256, uint256, address) {
        uint256 totalAmount = _calcTotalRecv(_prodid);
        return (_prodTimeLocks[_prodid].totalLocks, _prodTimeLocks[_prodid].totalGains, totalAmount.sub(_prodTimeLocks[_prodid].totalGains), _prodTimeLocks[_prodid].owner);
    }
    
    function _calcTotalRecv(uint256 _prodid) internal view returns(uint256) {
        uint256 startLockTime = _prods[_prodid].endTime.div(DAYTIME).mul(DAYTIME);
        uint256 dayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        VendorInfo memory _vendor = _vendors[_prods[_prodid].vendorid];
        if (_vendor.state == VendorState.DISABLED && dayTime > _vendor.disableTime) {
            dayTime = _vendor.disableTime;
        }
        
        if (dayTime <= startLockTime) {
            return 0;
        }
        uint256 diffDay = dayTime.sub(startLockTime).div(DAYTIME);
        if (diffDay > _prods[_prodid].effectPeriod) {
            return _prodTimeLocks[_prodid].totalLocks;
        } else {
            return _prodTimeLocks[_prodid].totalLocks.mul(diffDay).div(_prods[_prodid].effectPeriod);
        }
    }
    
}