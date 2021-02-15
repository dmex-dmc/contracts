//SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.7.0;
pragma experimental ABIEncoderV2;

import "./Address.sol";
import "./SafeMath.sol";
import "./Governance.sol";
import "./IERC721.sol";
import "./TransferHelper.sol";

contract CloudMinerDex is Governance {
    
    using SafeMath for uint256;
    using Address for address;
    
    address private verifyingContract;
    bytes32 private DOMAIN_SEPARATOR;
    uint256 private constant chainId = 128;
    bytes32 private constant salt = 0x3a57ef911e7e271df30e8aee1209724c8e2cd9ea4c9242162fe23bee8a9e5d74;
    
    string private constant EIP712_DOMAIN  = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)";
    string private constant ORDER_TYPE = "TradeOrder(address makerAddr,uint256 nftid,address tokenAddr,uint256 txAmount,uint256 expireTime)";

    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(abi.encodePacked(EIP712_DOMAIN));
    bytes32 private constant ORDER_TYPEHASH = keccak256(abi.encodePacked(ORDER_TYPE));
    address private constant cloudMiner = 0x7DDA78646ac44B2b1EB9B67aA74b0EbcdA1839e0;
    address private constant fundAddr = 0xb40eA8ca2DCcae0864e7Ff4dfb1bfdd4D990b5a9;
    
    uint256 public feeRate;
    
    mapping(bytes32 => bool) private _orderRecord;
    
    event TradeOrder(address indexed maker, address indexed taker, uint256 indexed tokenid, bytes32 txid, address tokenAddr, uint256 txAmount);
    event SetTxFee(uint256 indexed oldTxFee, uint256 indexed newTxFee);
	
    struct FillOrder {
        address makerAddr;
        uint256 nftid;
        address tokenAddr;
        uint256 txAmount;
		uint256 expireTime;
    }
    
    constructor() public {
        feeRate = 10;
        verifyingContract = address(this);
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256("CloudMiner Dex"),
            keccak256("1.0"),
            chainId,
            verifyingContract,
            salt
        ));
    }
    
    function setTxFee(uint256 newFee) external onlyGovernance {
		emit SetTxFee(feeRate, newFee);
        feeRate = newFee;
    }
    
    function encodeOrderHash(bytes memory makerData) external view returns(bytes32, address) {
        (FillOrder memory order, bytes memory signature) = abi.decode(makerData, (FillOrder, bytes));
        
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signature);
        bytes32 orderHash = hashTradeOrder(order);
        return (orderHash, ecrecover(orderHash, v, r, s));
    }
    
    function tradeNFT(bytes memory makerData) public {
        (FillOrder memory order, bytes32 txid) = assertTransaction(makerData);
        
        uint256 fees = order.txAmount.mul(feeRate).div(100);
        TransferHelper.safeTransferFrom(order.tokenAddr, msg.sender, fundAddr, fees);
        TransferHelper.safeTransferFrom(order.tokenAddr, msg.sender, order.makerAddr, order.txAmount.sub(fees));
        TransferHelper.safeTransferFrom(cloudMiner, order.makerAddr, msg.sender, order.nftid);
        _orderRecord[txid] = true;
        emit TradeOrder(order.makerAddr, msg.sender, order.nftid, txid, order.tokenAddr, order.txAmount);
    }
    
    function assertTransaction(bytes memory makerData) private view returns(
        FillOrder memory,
        bytes32
    ){
        (FillOrder memory order, bytes memory signature) = abi.decode(makerData, (FillOrder, bytes));
        
        bytes32 txid = keccak256(abi.encodePacked(signature));
        require(_orderRecord[txid] == false, "order exists!");
        require(block.timestamp < order.expireTime, "order expire!");
        require(IERC721(cloudMiner).ownerOf(order.nftid) == order.makerAddr, "maker not NFT owner");
        
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signature);
        require(order.makerAddr == ecrecover(hashTradeOrder(order), v, r, s), "Invalid Signature!");

        return (order, txid);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65, "Not Invalid Signature Data");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function hashTradeOrder(FillOrder memory order) private view returns (bytes32){
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                ORDER_TYPEHASH,
                order.makerAddr,
                order.nftid,
                order.tokenAddr,
                order.txAmount,
                order.expireTime
            ))
        ));
    }
    
}