//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./SafeMath.sol";
import "./ERC20.sol";
import "./Vistor.sol";

contract DMCToken is ERC20, Vistor{
    using SafeMath for uint256;
        
    address public constant DAOFUND = 0xfF20B0760AA62a49563B54a90E15C5b1214D65F1;
    address public constant DMEXFUND = 0x4EE8cdcDACAfB5C469157B764ef9612B8f351c0D;
    address public constant TEAMLOCK = 0xceb4273ace3685231f6aEc33e93C52b4d56848c0;
    address public constant PELOCK = 0x437D6B5d91A4fdE1959213Ac14168E2495609a7A;
	
	uint256 public constant TOTAL_MINING = 10 ** 18 * 50000000;
	uint256 public currentMintAmount;
    
	constructor() ERC20("Decentralized Mining Coin","DMC") public {
	    uint256 decimals = 10 ** 18;
	    _mint(DAOFUND, 10000000 * decimals);
	    _mint(DMEXFUND, 10000000 * decimals);
	    _mint(TEAMLOCK, 10000000 * decimals);
	    _mint(PELOCK, 20000000 * decimals);
	    
	}
	
	function mint(address _to, uint256 _amount) external onlyVistor {
	    if(_amount == 0 || currentMintAmount == TOTAL_MINING) {
	        return;
	    }
		uint256 tmp_amount = currentMintAmount.add(_amount);
		if(currentMintAmount < TOTAL_MINING && tmp_amount > TOTAL_MINING) {
		    _amount = TOTAL_MINING.sub(currentMintAmount);
		    tmp_amount = TOTAL_MINING;
		}
		require(tmp_amount <= TOTAL_MINING, "Exceeding the total amount of mining");
		currentMintAmount = tmp_amount;
        _mint(_to, _amount);
    }
	
	
}