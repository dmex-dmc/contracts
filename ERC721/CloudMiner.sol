//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./ERC721.sol";
import "./ICloudMiner.sol";
import "./Vistor.sol";

contract CloudMiner is ICloudMiner, ERC721,Vistor {

    uint256 private _tokenid = 0;
    
	constructor() ERC721("DMEX Finance","CloudMiner") public {
	}
	
	function setBaseURI(string memory _baseURI) onlyGovernance public {
	    _setBaseURI(_baseURI);
	}
	
	function mint(address owner) onlyVistor external override returns(uint256) {
	    _tokenid++;
	    _mint(owner, _tokenid);
	    return _tokenid;
	}
	
	function burn(uint256 tokenId) external override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "CloudMiner: caller is not owner nor approved");
        _burn(tokenId);
    }
    
    function tokensOfOwner(address owner) external view override returns (uint256[] memory) {
        return _tokensOfOwner(owner);
    }
	
	function setTokenURI(uint256 tokenId, string memory tokenURI) external override {
	    require(_isApprovedOrOwner(_msgSender(), tokenId), "CloudMiner:caller is not owner nor approved");
		_setTokenURI(tokenId, tokenURI);
    }

}