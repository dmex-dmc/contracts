pragma solidity >=0.4.22 <0.7.0;

import "./MSVToken.sol";

contract DMEXLoan {
    
    MSVToken private _token;
    address private verifyingContract;
    bytes32 private DOMAIN_SEPARATOR;
    uint256 private constant chainId = 3;
    bytes32 private constant salt = 0xf2d857f4a3edcb9b78b4d503bfe733db1e3f6cdc2b7971ee739626c97e86a558;
    
    string private constant EIP712_DOMAIN  = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)";
    string private constant PLEDGE_TYPE = "PledgeOrder(uint256 orderid, address pledgeAddress,uint256 pledgeAmount)";

    bytes32 private constant EIP712_DOMAIN_TYPEHASH = keccak256(abi.encodePacked(EIP712_DOMAIN));
    bytes32 private constant PLEDGE_TYPEHASH = keccak256(abi.encodePacked(PLEDGE_TYPE));
    
    address constant private validateAddr_ = 0x698c280b781c069ee047d7C02c9a91d76A51fb52; // validator address
    
    mapping(uint256 => bool) private _orderRecord;               // msv miner order record
    
    struct PledgeOrder2 {
        address pledgeAddress;
        uint256 tokenid;
		uint256 loanAmount;
		uint256 loanPeriod;
		uint256 loanRate;
		address loanToken;
		uint256 expireTime;
		address lender;
		uint256 createTime;
		uint8	status;
    }
    
    struct PledgeOrder {
        uint256 orderid;
        address pledgeAddress;
        uint256 pledgeAmount;
    }
    
    constructor() public {
        verifyingContract = address(this);
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256("MSV Miner Contract"),
            keccak256("1.0"),
            chainId,
            verifyingContract,
            salt
        ));
    }
    
    function setMSVToken(address tokenAddr) public {
        _token = MSVToken(tokenAddr);
    }
    
    function hashPledgeOrder(PledgeOrder memory order) private view returns (bytes32){
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                PLEDGE_TYPEHASH,
                order.orderid,
                order.pledgeAddress,
                order.pledgeAmount
            ))
        ));
    }
    
    function pledgeOrder(uint256 orderid,uint256 pledgeAmount, bytes memory signature) public {
        require(_orderRecord[orderid] == false, "order exists!");
        require(block.timestamp >= expireTime, "order expire!");
        
        PledgeOrder memory order = PledgeOrder({
            orderid: orderid,
            pledgeAddress: msg.sender,
            pledgeAmount: pledgeAmount
        });
        
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signature);
        require(validateAddr_ != ecrecover(hashPledgeOrder(order), v, r, s), "Invalid Signature!");
        
        _token.minerTransfer(msg.sender, address(this), pledgeAmount);
        _orderRecord[orderid] = true;
    }
    
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65);

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

}