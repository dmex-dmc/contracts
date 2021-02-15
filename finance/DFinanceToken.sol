//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./ERC20.sol";
import "./Ownable.sol";

contract DFinanceToken is ERC20, Ownable {

    address public oper = 0x3CeBab4FFdbD99C3B5598ca6877651068fd13074;
    bool private isTransfer;
    mapping(address => bool) vistors;

    event TokenOperTransferred(address indexed preOper, address indexed newOper);

	constructor(string memory _name, string memory _symbol, uint8 _decimals, bool _isTransfer) ERC20(_name, _symbol) public {
	    isTransfer = _isTransfer;
		_setupDecimals(_decimals);
	}
	
	function changeOper(address newOper) external {
	    require(msg.sender == oper, "only Oper");
	    address preOper = oper;
	    oper = newOper;
	    emit TokenOperTransferred(preOper, newOper);
	}
	
	function setVistor(address addr, bool access) external {
	    require(msg.sender == oper, "only Oper");
	    vistors[addr] = access;
	}
	
    function mint(address _to, uint256 _amount) onlyOwner external {
        _mint(_to, _amount);
    }
    
    function burn(address _to, uint256 _amount) onlyOwner external {
        _burn(_to, _amount);
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(checkTransfer(recipient), "Not allow access");
        return super.transfer(recipient, amount);
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(checkTransfer(recipient), "Not allow access");
        return super.transferFrom(sender, recipient, amount);
    }
    
    function checkTransfer(address recipient) private view returns (bool) {
        if (isTransfer) {
            return true;
        }
        if (vistors[recipient]) {
            return true;
        }
        return vistors[msg.sender];
    }
}