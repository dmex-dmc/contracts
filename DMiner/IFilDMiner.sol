//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./IFilDMinerStorage.sol";
import "./IDMexVendor.sol";
import "./IDMexAirdrop.sol";
import "./SafeMath.sol";
import "./Vistor.sol";
import "./Address.sol";
import "./ICloudMiner.sol";

contract IFilDMiner is IFilDMinerStorage,IDMexVendorStorage,Vistor {
    using SafeMath for uint256;
    using Address for address;
    
    event DepositBenefit(uint256 indexed prodid, uint256 dayTime, uint256 mineAmount);
    event Withdraw(address indexed user, uint256 amount);
    event Exchange(address indexed user, uint256 amount, string ifilAddr);
    event BuyIFilNFT(address indexed user, uint256 tokenid, uint256 prodid, uint256 payAmount, uint256 power);
    event UserRegister(address indexed user, bytes32 inviteCode);
    event InviteReward(address indexed user, address indexed inviter, uint256 amount);
    event ChangeIFilFunder(address indexed oldAddr, address indexed newAddr);
    event ChangeAirdrop(address indexed _airdrop);
    event RecvAirdrop(address indexed user, uint256 indexed tokenid, uint256 prodid, uint256 power);
    
    IDMexVendor private constant dmexVendor = IDMexVendor(0x5A65d56A86D94BcB24d8Ce8b5ED0319a3754d6B2);
    ICloudMiner private constant cloudMiner = ICloudMiner(0x7DDA78646ac44B2b1EB9B67aA74b0EbcdA1839e0);
    address private constant hfilToken = 0xae3a768f9aB104c69A7CD6041fE16fFa235d1810;
    
    bytes4 private constant ERC20_TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private constant ERC20_TRANSFERFROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
    address private constant usdt = 0x0298c2b32eaE4da002a15f36fdf7615BEa3DA047;
    
    address private constant fundAddr = 0xb40eA8ca2DCcae0864e7Ff4dfb1bfdd4D990b5a9;
    
    bytes32 private constant OFFICAL_UID = 0x444d455800000000000000000000000000000000000000000000000000000000;
    
    uint256 private constant FEERATE = 5;               //back pay usdt * feeRate / 100 to fundAddr
    uint256 private constant DAYTIME = 86400;
    uint256 private constant fixedRate = 25;            //fixed release rate
    uint256 private constant linearRate = 75;           //linear release
    uint256 private constant linearReleaseDay = 180;     //linear release day
    
    address public airdrop;
    bool public _initialize;
    
    function initialize() public {
        require(_initialize == false, "already initialized");
        _initialize = true;
        _governance = msg.sender;
        _users[fundAddr].uid = OFFICAL_UID;
        _uids[OFFICAL_UID] = fundAddr;
    }
    
    function setAirdrop(address _addr) onlyGovernance public {
        airdrop = _addr;
        emit ChangeAirdrop(_addr);
    }
    
    function depositBenefits(uint256 _prodid, uint256 _effectPower, uint256 _mineBenefits) onlyVistor public {
        _safeTransferFrom(hfilToken, msg.sender, address(this), _mineBenefits);
        
        uint256 _dayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        _beftPools[_prodid][_dayTime].fixedMineAmount += _mineBenefits.mul(fixedRate).div(100);
        _beftPools[_prodid][_dayTime].linearMineAmount += _mineBenefits.mul(linearRate).div(100);
        _beftPools[_prodid][_dayTime].effectPower = _effectPower;
        emit DepositBenefit(_prodid, _dayTime, _mineBenefits);
    }
    
    function createNFT(bytes32 _inviterid, uint256 _prodid, uint256 _buyAmount, uint256 _payment) public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        if (prod.startTime > 0) {
            require(block.timestamp >= prod.startTime, "It's not time to buy yet");
        }
        
        uint256 _recvPower = _buyAmount.mul(prod.power);
        
        if (_users[msg.sender].inviter == address(0)) {
            require(_uids[_inviterid] != address(0) && _uids[_inviterid] != msg.sender, "error inviter");
            _users[msg.sender].inviter = _uids[_inviterid];
            
            _users[_uids[_inviterid]].invitees.push(msg.sender);
        }
        
        uint256 needPayAmount = _buyAmount.mul(prod.price);
        require(_payment == needPayAmount, "price not correct");
        
        address inviter = _users[msg.sender].inviter;
        uint256 needPayFee = needPayAmount.mul(FEERATE).div(100);
        uint256 inviteRewards = needPayAmount.mul(_getRebateRate(inviter)).div(100);
        
        _safeTransferFrom(usdt, msg.sender, fundAddr, needPayFee);
        _safeTransferFrom(usdt, msg.sender, inviter, inviteRewards);
        
        uint256 sendAmount = needPayAmount.sub(needPayFee).sub(inviteRewards);
        _safeTransferFrom(usdt, msg.sender, address(dmexVendor), sendAmount);
        dmexVendor.settlementAndTimeLock(_prodid, msg.sender, _recvPower, sendAmount);
        
        emit InviteReward(msg.sender, inviter, inviteRewards);
        
        uint256 curDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        uint256 tokenid = cloudMiner.mint(msg.sender);
        _ifilNfts[tokenid].prodid = _prodid;
        _ifilNfts[tokenid].power = _recvPower;
        _ifilNfts[tokenid].createTime = block.timestamp;
        _ifilNfts[tokenid].activeTime = curDayTime.add(prod.activePeriod.mul(DAYTIME));
        _ifilNfts[tokenid].expireTime = _ifilNfts[tokenid].activeTime.add(prod.effectPeriod.mul(DAYTIME));
        _prodNfts[_prodid].push(tokenid);
        
        emit BuyIFilNFT(msg.sender, tokenid, _prodid, needPayAmount, _recvPower);
    }
    
    function userRegister(bytes32 inviteCode) public {
        require(inviteCode != 0x0, "invalid inviteCode");
        require(_uids[inviteCode] == address(0), "The invitation code has been registered");
        require(_users[msg.sender].uid == 0x0, "The user has been registered");
        _users[msg.sender].uid = inviteCode;
        _uids[inviteCode] = msg.sender;
        emit UserRegister(msg.sender, inviteCode);
    }
    
    function recvAirdrop() public {
        (uint256 _prodid, uint256 _power) = IDMexAirdrop(airdrop).recvAirdrop(msg.sender);
        require(dmexVendor.getProduct(_prodid).prodType == 2, "Non-Airdrop Product");
        
        uint256 curDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
		
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        uint256 tokenid = cloudMiner.mint(msg.sender);
        _ifilNfts[tokenid].prodid = _prodid;
        _ifilNfts[tokenid].power = _power;
        _ifilNfts[tokenid].createTime = block.timestamp;
        _ifilNfts[tokenid].activeTime = curDayTime.add(prod.activePeriod.mul(DAYTIME));
        _ifilNfts[tokenid].expireTime = _ifilNfts[tokenid].activeTime.add(prod.effectPeriod.mul(DAYTIME));
        _prodNfts[_prodid].push(tokenid);
        
        emit RecvAirdrop(msg.sender, tokenid, _prodid, _power);
    }
    
    function withdrawBenefits() public {
        uint256[] memory _tokens = cloudMiner.tokensOfOwner(msg.sender);
        if (_tokens.length <= 0) {
            return;
        }
        uint256 totalBenefits = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            IFilNFT storage ifilNFT = _ifilNfts[_tokens[i]];
            (uint256 nftBenefits, ) = _calcNFTBenefits(_tokens[i]);
            if (nftBenefits > ifilNFT.gainBenefits) {
                totalBenefits += nftBenefits.sub(ifilNFT.gainBenefits);
                ifilNFT.gainBenefits = nftBenefits;
            }
        }
        _users[msg.sender].gainBenefits += totalBenefits;
        _safeTransfer(hfilToken, msg.sender, totalBenefits);
        emit Withdraw(msg.sender, totalBenefits);
    }
    
    function withdrawBenefits(uint256[] memory _tokens) public {
        uint256 totalBenefits = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(cloudMiner.ownerOf(_tokens[i]) == msg.sender, "not owner withdraw");
            IFilNFT storage ifilNFT = _ifilNfts[_tokens[i]];
            (uint256 nftBenefits, ) = _calcNFTBenefits(_tokens[i]);
            if (nftBenefits > ifilNFT.gainBenefits) {
                totalBenefits += nftBenefits.sub(ifilNFT.gainBenefits);
                ifilNFT.gainBenefits = nftBenefits;
            }
        }
        _users[msg.sender].gainBenefits += totalBenefits;
        _safeTransfer(hfilToken, msg.sender, totalBenefits);
        emit Withdraw(msg.sender, totalBenefits);
    }
    

    
    function getBenefitPool(uint256 _prodid, uint256 _poolid) public view returns(BenefitPool memory) {
        return _beftPools[_prodid][_poolid];
    }
    
    function getAndCheckRecvAirdrop(address owner) public view returns(bool, bool, uint256, uint256) {
        (bool _available, bool _received, uint256 _power) = IDMexAirdrop(airdrop).checkAirdrop(owner);
        return (_available, _received, _power, IDMexAirdrop(airdrop).getAirdropEndTime());
    }
    
    function getUserInfo(address owner) public view returns(BackUser memory) {
        uint256[] memory _tokens = cloudMiner.tokensOfOwner(owner);
        
        uint256 effectPower = 0;
        uint256 _nftTotalBenefits = 0;
        uint256 _nftGainBenefits = 0;
        uint256 _unreleaseBenefits = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            {
                (uint256 calcTotalBenefits, uint256 calcUnreleaseBenefits) = _calcNFTBenefits(_tokens[i]);
                _nftTotalBenefits += calcTotalBenefits;
                _unreleaseBenefits += calcUnreleaseBenefits;
                _nftGainBenefits += _ifilNfts[_tokens[i]].gainBenefits;
                if (block.timestamp < _ifilNfts[_tokens[i]].expireTime) {
                    effectPower += _ifilNfts[_tokens[i]].power;
                }
            }
        }
        
        return BackUser({
            uid:            _users[owner].uid,
            inviter:        _users[owner].inviter,
            inviteeNum:     _users[owner].invitees.length,
            tokenNum:       _tokens.length,
            ugrade:         _users[owner].ugrade,
            effectPower:    effectPower,
            received:       _users[owner].gainBenefits,
            available:      _nftTotalBenefits.sub(_nftGainBenefits),
            unreleased:     _unreleaseBenefits
        });
    }
    
    function getInviter(bytes32 inviterid) public view returns(address) {
        return _uids[inviterid];
    }
    
    function getNFTInfo(uint256 tokenid) public view returns(IFilNFT memory, uint256, uint256) {
        IFilNFT memory nft = _ifilNfts[tokenid];
        (uint256 calcTotalBenefits, uint256 calcUnreleaseBenefits) = _calcNFTBenefits(tokenid);
        return (nft, calcTotalBenefits, calcUnreleaseBenefits);
    }
    
    function getNFTInfos(uint256[] memory tokenids) public view returns(IFilNFT[] memory) {
        IFilNFT[] memory nfts = new IFilNFT[](tokenids.length);
        for (uint256 i = 0; i< tokenids.length; i++) {
            nfts[i] = _ifilNfts[tokenids[i]];
        }
        return nfts;
    }
    
    function getNFTPeriodBenefits(uint256 _tokenid, uint256 _startTime, uint256 _endTime) public view returns(uint256[] memory, uint256[] memory) {
        _startTime = _startTime.div(DAYTIME).mul(DAYTIME);
        _endTime = _endTime.div(DAYTIME).mul(DAYTIME);
        
        uint256 diffDay = _endTime.sub(_startTime).div(DAYTIME);
        uint256[] memory dayTimeList = new uint256[](diffDay + 1);
        uint256[] memory dayBenefitList = new uint256[](diffDay + 1);
        uint256 index = 0;
        for (uint256 i = _startTime; i <= _endTime; i = i + DAYTIME) {
            dayTimeList[index] = i;
            dayBenefitList[index] = _calcDayBenefits(_tokenid, i);
            index++;
        }
        
        return (dayTimeList, dayBenefitList);
    }
    
    function getNFTDayBenefits(uint256 _tokenid, uint256 _dayTime) public view returns(uint256) {
        _dayTime = _dayTime.div(DAYTIME).mul(DAYTIME);
        return _calcDayBenefits(_tokenid, _dayTime);
    }
    
    function getDayBenefitsByTokens(uint256[] memory _tokens, uint256 _dayTime) public view returns(uint256[] memory) {
        _dayTime = _dayTime.div(DAYTIME).mul(DAYTIME);
        uint256[] memory _totalBenefits = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            _totalBenefits[i] = _calcDayBenefits(_tokens[i], _dayTime);
        }
        
        return _totalBenefits;
    }
    
    function getEffectPower(uint256 _prodid) public view returns(uint256) {
        uint256[] memory ifilTokens = _prodNfts[_prodid];
        uint256 effectPower = 0;
        for (uint256 i=0 ; i < ifilTokens.length ; i++) {
            IFilNFT memory ifilNFT = _ifilNfts[ifilTokens[i]];
            if (block.timestamp >= ifilNFT.activeTime && block.timestamp < ifilNFT.expireTime) {
                effectPower += ifilNFT.power;
            }
        }
        return effectPower;
    }
    
    function _getRebateRate(address inviter) private view returns(uint256) {
        if (_users[inviter].invitees.length <= 3) {
            return 4;
        } else if (_users[inviter].invitees.length <= 8) {
            return 5;
        } else {
            return 6;
        }
    }
    
    function _calcNFTBenefits(uint256 tokenid) private view returns(uint256, uint256) {
        IFilNFT memory ifilNFT = _ifilNfts[tokenid];
        
        uint256 curDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        uint256 endDayTime = curDayTime;
        if (endDayTime >= ifilNFT.expireTime) {
            endDayTime = ifilNFT.expireTime.sub(1);
        }
        uint256 _totalBenefits = 0;
        uint256 _unreleaseBenefits = 0;
        for (uint256 i = ifilNFT.activeTime; i <= endDayTime; i = i + DAYTIME) {
            BenefitPool memory benefitPool = _beftPools[ifilNFT.prodid][i];
            if (benefitPool.effectPower > 0) {
                _totalBenefits += benefitPool.fixedMineAmount.mul(ifilNFT.power).div(benefitPool.effectPower);
                
                uint256 diffDay = curDayTime.sub(i).div(DAYTIME);
                if (diffDay > 0 && diffDay > linearReleaseDay) {
                    diffDay = linearReleaseDay;
                }
                _totalBenefits += benefitPool.linearMineAmount.mul(diffDay).mul(ifilNFT.power).div(linearReleaseDay).div(benefitPool.effectPower);
                _unreleaseBenefits += benefitPool.linearMineAmount.mul(linearReleaseDay.sub(diffDay)).mul(ifilNFT.power).div(linearReleaseDay).div(benefitPool.effectPower);
            }
        }
        return (_totalBenefits, _unreleaseBenefits);
    }
    
    function _calcDayBenefits(uint256 tokenid, uint256 _dayTime) private view returns(uint256) {
        IFilNFT memory ifilNFT = _ifilNfts[tokenid];
        if (_dayTime < ifilNFT.activeTime || _dayTime >= ifilNFT.expireTime.add(linearReleaseDay.mul(DAYTIME))) {
            return 0;
        }
        
        uint256 _totalBenefits = 0;
        BenefitPool memory benefitPool = _beftPools[ifilNFT.prodid][_dayTime];
        if (_dayTime >= ifilNFT.activeTime && _dayTime < ifilNFT.expireTime && benefitPool.effectPower > 0) {
            _totalBenefits += benefitPool.fixedMineAmount.mul(ifilNFT.power).div(benefitPool.effectPower);
        }
        
        for (uint256 i = ifilNFT.activeTime; i < ifilNFT.expireTime; i += DAYTIME) {
            if (_dayTime > i && _dayTime <= i.add(linearReleaseDay.mul(DAYTIME)) && benefitPool.effectPower > 0) {
                _totalBenefits += benefitPool.linearMineAmount.mul(ifilNFT.power).div(linearReleaseDay).div(benefitPool.effectPower);
            }
        }
        return _totalBenefits;
    }
    
    function _safeTransfer(address _token, address _to, uint256 _amount) private {
        bytes memory returnData = _token.functionCall(abi.encodeWithSelector(
            ERC20_TRANSFER_SELECTOR,
            _to,
            _amount
        ), "ERC20: transfer call failed");
        
        if (returnData.length > 0) { // Return data is optional
            require(abi.decode(returnData, (bool)), "ERC20: transfer did not succeed");
        }
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