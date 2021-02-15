// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import "./IERC721.sol";

interface ICloudMiner is IERC721 {
   
	function mint(address owner) external returns(uint256);
	
	function burn(uint256 tokenId) external;
    
	function tokensOfOwner(address owner) external view returns (uint256[] memory) ;
	
	function setTokenURI(uint256 tokenId, string memory tokenURI) external;
}
