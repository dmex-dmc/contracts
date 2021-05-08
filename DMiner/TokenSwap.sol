// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Governance.sol";
import "./Address.sol";

contract TokenSwap is Governance {
    using Address for address;
    
    struct TokenPair {
        address token1;
        uint256 minAmount;
        string symbol2;
    }
    
    bytes4 private constant ERC20_TRANSFERFROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
    address private constant blackhole = 0x0000000000000000000000000000000000000001;
    
    event AddPair(uint256 indexed pid, address indexed token1, string indexed symbol2, uint256 miniAmount);
    event Swap(uint256 indexed pid, address indexed from, string to, uint256 amount);
    event SetMinAmount(uint256 indexed pid, uint256 miniAmount);
    
    mapping(uint256 => TokenPair) internal pairs;
    uint256[] internal pids;
    
    bool public _initialize;
    
    function initialize() public {
        require(_initialize == false, "already initialized");
        _initialize = true;
        _governance = msg.sender;
    }
    
    function addPair(uint256 _pid, address _token1, string memory _symbol2, uint256 _minAmount) onlyGovernance external {
        require(_token1 != address(0x0), "token1 address is zero");
        require(pairs[_pid].token1 == address(0x0), "token pair already exists");
        pairs[_pid] = TokenPair({
            token1: _token1,
            symbol2: _symbol2,
            minAmount: _minAmount
        });
        pids.push(_pid);
        emit AddPair(_pid, _token1, _symbol2, _minAmount);
    }
    
    function swap(uint256 _pid, address _from, string memory _to, uint256 _amount) external {
        require(pairs[_pid].token1 != address(0x0), "token1 address is zero");
        require(_amount > 0 && _amount >= pairs[_pid].minAmount, "minimum number of exchanges");
        
        _safeTransferFrom(pairs[_pid].token1, _from, blackhole, _amount);
        emit Swap(_pid, _from, _to, _amount);
    }
    
    function setMinAmount(uint256 _pid, uint256 _minAmount) onlyGovernance external {
        pairs[_pid].minAmount = _minAmount;
        emit SetMinAmount(_pid, _minAmount);
    }
    
    function getMinAmount(uint256 _pid) external view returns(uint256) {
        return pairs[_pid].minAmount;
    }
    
    
    function getTokenPair(uint256 _pid) external view returns(TokenPair memory) {
        return pairs[_pid];
    }
    
    function getPids() external view returns(uint256[] memory) {
        return pids;
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