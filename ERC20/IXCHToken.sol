//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./ERC20.sol";
import "./IDMEXToken.sol";
import "./Vistor.sol";

contract IXCHToken is IDMEXToken, ERC20, Vistor{
    
    bool public _initialize;

	constructor() ERC20("IXCH TOKEN","IXCH") public {
	}
	
	 function initialize() public {
        require(_initialize == false, "already initialized");
        _initialize = true;
        _governance = msg.sender;
    }
	
    function mint(uint256 _amount) onlyGovernance override external {
        _mint(msg.sender, _amount);
    }
    
    function burn(uint256 _amount) external override {
        _burn(msg.sender, _amount);
    }
    
}