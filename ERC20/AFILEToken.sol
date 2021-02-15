//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./ERC20.sol";
import "./IDMEXToken.sol";
import "./Vistor.sol";

contract AFILToken is IDMEXToken, ERC20, Vistor{

	constructor() ERC20("AFIL TOKEN","AFIL") public {
	}
	
    function mint(uint256 _amount) onlyVistor override external {
        _mint(msg.sender, _amount);
    }
    
    function burn(uint256 _amount) external override {
        _burn(msg.sender, _amount);
    }
    
}