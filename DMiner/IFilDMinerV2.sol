//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./IFilDMinerStorageV2.sol";
import "./IDMexVendorV2.sol";
import "./IDMexAirdrop.sol";
import "./SafeMath.sol";
import "./Vistor.sol";
import "./Address.sol";
import "./ICloudMiner.sol";

contract IFilDMinerV2 is IFilDMinerStorageV2,IDMexVendorStorageV2,Vistor {
    using SafeMath for uint256;
    using Address for address;
    
    event DepositBenefit(uint256 indexed prodid, uint256 dayTime, uint256 mineAmount, uint256 linerBenefits);
    event Withdraw(address indexed user, uint256 amount);
    event Exchange(address indexed user, uint256 amount, string ifilAddr);
    event BuyIFilNFT(address indexed user, uint256 tokenid, uint256 prodid, uint256 payAmount, uint256 power);
    event UserRegister(address indexed user, bytes32 inviteCode);
    event InviteReward(address indexed user, address indexed inviter, uint256 amount);
    event ChangeIFilFunder(address indexed oldAddr, address indexed newAddr);
    event ChangeAirdrop(address indexed _airdrop);
    event RecvAirdrop(address indexed user, uint256 indexed tokenid, uint256 prodid, uint256 power);
    event CreateNFT(address indexed user, uint256 indexed tokenid, uint256 prodid, uint256 power);
    event MergeNft(address indexed user, uint256 prodid, uint256[] tokenids);
    event SplitNft(uint256 prodid, uint256 indexed tokenid, uint256[] powers);
    event DestroyNFT(address indexed user, uint256 indexed tokenid, uint256 prodid);
    event ReturnPledge(address indexed user, uint256 amount);
    event ChargePledge(uint256 prodid, uint256 amount);
    event SetMaxBuyPower(uint256 prodid, uint256 maxBuyPower);
    
    IDMexVendorV2 private constant dmexVendor = IDMexVendorV2(0x0FB8d08a7E3090c1F1B6cDd55D345024605e0F26);
    ICloudMiner private constant cloudMiner = ICloudMiner(0x36Ca8Eaf6Eaa1c4fA1c5FC62bF0b8Acd45eF55EC);
    
    bytes4 private constant ERC20_TRANSFER_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private constant ERC20_TRANSFERFROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
    
    address private constant fundAddr = 0x753163099e934Edace8d7d8937BaA9b1A81373a9;
    
    bytes32 private constant OFFICAL_UID = 0x444d455800000000000000000000000000000000000000000000000000000000;
    
    uint256 private constant FEERATE = 5;               //back pay usdt * feeRate / 100 to fundAddr
    uint256 private constant DAYTIME = 86400;
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
    
    function depositBenefits(uint256 _prodid, uint256 _effectPower, uint256 _mineBenefits, uint256 _linerBenefits) onlyVistor public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        _safeTransferFrom(prod.benefitsToken, msg.sender, address(this), _mineBenefits);
        
        uint256 _dayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        _beftPools[_prodid][_dayTime].fixedMineAmount += _mineBenefits;
        _beftPools[_prodid][_dayTime].linearMineAmount += _linerBenefits;
        _beftPools[_prodid][_dayTime].effectPower = _effectPower;
        emit DepositBenefit(_prodid, _dayTime, _mineBenefits, _linerBenefits);
    }
    
    function createNFT(bytes32 _inviterid, uint256 _prodid, uint256 _buyAmount, uint256 _payment) public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        if (prod.startTime > 0) {
            require(block.timestamp >= prod.startTime, "It's not time to buy yet");
        }
        require(prod.price > prod.pledgeAmount, "pledge amount should less than price");

        uint256 activeTime = prod.startTime.div(DAYTIME).mul(DAYTIME).add(prod.activePeriod.mul(DAYTIME));
        uint256 expireTime = activeTime.add(prod.effectPeriod.mul(DAYTIME));
        require(block.timestamp <= expireTime, "The sale is over");
        
        uint256 _recvPower = _buyAmount.mul(prod.power);
        uint256 needPayAmount = _buyAmount.mul(prod.price);
        require(_payment == needPayAmount, "price not correct");
        
        uint256 alreadyBuyPower = _maxBuyPowers[_prodid][msg.sender];
        require(alreadyBuyPower.add(_buyAmount) <= prod.maxBuyPower, "Limit the number of products purchased");
        _maxBuyPowers[_prodid][msg.sender] = _maxBuyPowers[_prodid][msg.sender].add(_buyAmount);
        
        
        uint256 needPayFee = needPayAmount.mul(FEERATE).div(100);
        
        _safeTransferFrom(prod.payToken, msg.sender, fundAddr, needPayFee);
        
        uint256 sendAmount = needPayAmount.sub(needPayFee);
        _safeTransferFrom(prod.payToken, msg.sender, address(dmexVendor), sendAmount);
        dmexVendor.settlementAndTimeLock(_prodid, msg.sender, _recvPower, sendAmount);
        
        emit InviteReward(msg.sender, address(0x0), 0);
        
        (uint256 nftBenefits, ) = _calcNFTBenefitsV2(_prodid, _recvPower, activeTime, expireTime);
        if(nftBenefits > 0) {
            UserInfo storage userInfo = _users[msg.sender];
            userInfo.gainBenefits[prod.benefitsToken] = userInfo.gainBenefits[prod.benefitsToken].add(nftBenefits);
            _safeTransfer(prod.benefitsToken, msg.sender, nftBenefits);
            emit Withdraw(msg.sender, nftBenefits);
        }
    
        
        uint256 tokenid = cloudMiner.mint(msg.sender);
        _ifilNfts[tokenid].prodid = _prodid;
        _ifilNfts[tokenid].power = _recvPower;
        _ifilNfts[tokenid].createTime = block.timestamp;
        _ifilNfts[tokenid].activeTime = activeTime;
        _ifilNfts[tokenid].expireTime = expireTime;
        _ifilNfts[tokenid].gainBenefits = nftBenefits;
        _ifilNfts[tokenid].deleted = false;
        _ifilNfts[tokenid].benefitsToken = prod.benefitsToken;
        _prodNfts[_prodid].push(tokenid);
        
        
        emit BuyIFilNFT(msg.sender, tokenid, _prodid, needPayAmount, _recvPower);
    }
    
    
    function splitNft(uint256 _prodid, uint256 _tokenid, uint256[] memory _powers) public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        require(cloudMiner.ownerOf(_tokenid) == msg.sender, "not owner");
        
        IFilNFT storage nft = _ifilNfts[_tokenid];
        uint256 totalPowers = 0;
        for (uint256 i = 0; i < _powers.length; i++) {
            totalPowers = totalPowers.add(_powers[i]);
        }
        require(nft.power == totalPowers, "The total power is not equal");
        
        nft.deleted = true;
        cloudMiner.burn(_tokenid);
        emit DestroyNFT(msg.sender, _tokenid, _prodid);
        
        for (uint256 i = 0; i < _powers.length; i++) {
           _createNft(_prodid, _powers[i], nft.gainBenefits.mul(_powers[i]).div(totalPowers), prod.benefitsToken); 
        }
        
        emit SplitNft(_prodid, _tokenid, _powers);
    }
    
    function mergeNft(uint256 _prodid, uint256[] memory _tokenids) public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        
        uint256 gainBenefits = 0;
        uint256 power = 0;
        for (uint256 i = 0; i < _tokenids.length; i++) {
            require(cloudMiner.ownerOf(_tokenids[i]) == msg.sender, "not owner");
            IFilNFT storage ifilNFT = _ifilNfts[_tokenids[i]];
            gainBenefits = gainBenefits.add(ifilNFT.gainBenefits);
            power = power.add(ifilNFT.power);
            ifilNFT.deleted = true;
            cloudMiner.burn(_tokenids[i]);
            emit DestroyNFT(msg.sender, _tokenids[i], _prodid);
        }
        
        _createNft(_prodid, power, gainBenefits, prod.benefitsToken);
        emit MergeNft(msg.sender, _prodid, _tokenids);
    }
    
    function burnNft(uint256 _prodid, uint256 _tokenid) public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        require(cloudMiner.ownerOf(_tokenid) == msg.sender, "not owner");
        
        uint256 curDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        IFilNFT storage ifilNFT = _ifilNfts[_tokenid];
        require(curDayTime >= ifilNFT.expireTime.add(linearReleaseDay.mul(DAYTIME)), "not end");
        
        uint256[] memory ids = new uint256[](1);
        ids[0] = _tokenid;
        withdrawBenefits(prod.benefitsToken, ids);
        
        uint256 amount = ifilNFT.power.mul(prod.pledgeAmount);
        if(amount > 0) {
            _safeTransfer(prod.payToken, msg.sender, amount);
            emit ReturnPledge(msg.sender, amount);
        }
        
        ifilNFT.deleted = true;
        cloudMiner.burn(_tokenid);
        emit DestroyNFT(msg.sender, _tokenid, _prodid);    
    }
    
    function chargePledge(uint256 _prodid, uint256 _amount) onlyGovernance public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        
        uint256 activeTime = prod.startTime.div(DAYTIME).mul(DAYTIME).add(prod.activePeriod.mul(DAYTIME));
        uint256 expireTime = activeTime.add(prod.effectPeriod.mul(DAYTIME));
        require(block.timestamp > expireTime, "The sale is not over");
        
        
        uint256 needAmount = prod.soldPower.mul(prod.pledgeAmount);
        require(needAmount == _amount, "Insufficient recharge");
        
        _safeTransferFrom(prod.payToken, msg.sender, address(this), _amount);
        emit ChargePledge(_prodid, _amount);
    }
    
    
    function _createNft(uint256 _prodid, uint256 _power, uint256 _gainBenefits, address benefitsToken) internal {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        
        uint256 startTime = prod.startTime.div(DAYTIME).mul(DAYTIME);
        uint256 tokenid = cloudMiner.mint(msg.sender);
        _ifilNfts[tokenid].prodid = _prodid;
        _ifilNfts[tokenid].power = _power;
        _ifilNfts[tokenid].createTime = block.timestamp;
        _ifilNfts[tokenid].activeTime = startTime.add(prod.activePeriod.mul(DAYTIME));
        _ifilNfts[tokenid].expireTime = _ifilNfts[tokenid].activeTime.add(prod.effectPeriod.mul(DAYTIME));
        _ifilNfts[tokenid].gainBenefits = _gainBenefits;
        _ifilNfts[tokenid].deleted = false;
        _ifilNfts[tokenid].benefitsToken = benefitsToken;
        _prodNfts[_prodid].push(tokenid);
        
        emit CreateNFT(msg.sender, tokenid, _prodid, _power);
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
    
    function withdrawBenefits(address benefitsToken) public {
        uint256[] memory _tokens = cloudMiner.tokensOfOwner(msg.sender);
        if (_tokens.length <= 0) {
            return;
        }
        uint256 totalBenefits = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            IFilNFT storage ifilNFT = _ifilNfts[_tokens[i]];
            if(ifilNFT.benefitsToken != benefitsToken) {
                continue;
            }
            (uint256 nftBenefits, ) = _calcNFTBenefits(_tokens[i]);
            if (nftBenefits > ifilNFT.gainBenefits) {
                totalBenefits += nftBenefits.sub(ifilNFT.gainBenefits);
                ifilNFT.gainBenefits = nftBenefits;
            }
        }
        UserInfo storage userInfo = _users[msg.sender];
        userInfo.gainBenefits[benefitsToken] = userInfo.gainBenefits[benefitsToken].add(totalBenefits);
        _safeTransfer(benefitsToken, msg.sender, totalBenefits);
        emit Withdraw(msg.sender, totalBenefits);
    }
    
    function withdrawBenefits(address benefitsToken, uint256[] memory _tokens) public {
        uint256 totalBenefits = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(cloudMiner.ownerOf(_tokens[i]) == msg.sender, "not owner withdraw");
            IFilNFT storage ifilNFT = _ifilNfts[_tokens[i]];
            if(ifilNFT.benefitsToken != benefitsToken) {
                continue;
            }
            (uint256 nftBenefits, ) = _calcNFTBenefits(_tokens[i]);
            if (nftBenefits > ifilNFT.gainBenefits) {
                totalBenefits += nftBenefits.sub(ifilNFT.gainBenefits);
                ifilNFT.gainBenefits = nftBenefits;
            }
        }
        UserInfo storage userInfo = _users[msg.sender];
        userInfo.gainBenefits[benefitsToken] = userInfo.gainBenefits[benefitsToken].add(totalBenefits);
        _safeTransfer(benefitsToken, msg.sender, totalBenefits);
        emit Withdraw(msg.sender, totalBenefits);
    }
    

    
    function getBenefitPool(uint256 _prodid, uint256 _poolid) public view returns(BenefitPool memory) {
        return _beftPools[_prodid][_poolid];
    }
    
    function getAndCheckRecvAirdrop(address owner) public view returns(bool, bool, uint256, uint256) {
        (bool _available, bool _received, uint256 _power) = IDMexAirdrop(airdrop).checkAirdrop(owner);
        return (_available, _received, _power, IDMexAirdrop(airdrop).getAirdropEndTime());
    }
    
    function getUserInfo(address owner, address benefitsToken) public view returns(BackUser memory) {
        uint256[] memory _tokens = cloudMiner.tokensOfOwner(owner);
        
        uint256 effectPower = 0;
        uint256 _nftTotalBenefits = 0;
        uint256 _nftGainBenefits = 0;
        uint256 _unreleaseBenefits = 0;
        uint256 availTokens = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            {
                IFilNFT memory ifilNFT = _ifilNfts[_tokens[i]];
                if(ifilNFT.benefitsToken != benefitsToken) {
                    continue;
                }
                
                availTokens = availTokens.add(1);
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
            tokenNum:       availTokens,
            ugrade:         _users[owner].ugrade,
            effectPower:    effectPower,
            received:       _users[owner].gainBenefits[benefitsToken],
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
    
    function getNFTInfosByProductId(uint256 _prodid) public view returns(uint256[] memory, IFilNFT[] memory) {
        uint256[] memory _tokens = cloudMiner.tokensOfOwner(msg.sender);
        uint256 counts = 0;
        for(uint256 i = 0; i < _tokens.length; i++) {
            IFilNFT memory ifilNFT = _ifilNfts[_tokens[i]];
            if(ifilNFT.prodid == _prodid) {
                counts = counts.add(1);
            }
        }
        
        IFilNFT[] memory nfts = new IFilNFT[](counts);
        uint256[] memory ids = new uint256[](counts);
        uint256 k = 0;
        for (uint256 j = 0 ; j < _tokens.length; j++) {
            IFilNFT memory ifilNFT = _ifilNfts[_tokens[j]];
            if(ifilNFT.prodid == _prodid) {
                nfts[k] = ifilNFT;
                ids[k] = _tokens[j];
                k = k.add(1);
            }
        }
        return (ids, nfts);
    }
    
    function withdrawBenefitsByProductId(uint256 _prodid) public {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        require(prod.prodType == 1, "Non-purchasable Product");
        
        (uint256[] memory ids,)  = getNFTInfosByProductId(_prodid);
        withdrawBenefits(prod.benefitsToken, ids);
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
            if(ifilNFT.deleted) {
                continue;
            }
            if (block.timestamp >= ifilNFT.activeTime && block.timestamp < ifilNFT.expireTime) {
                effectPower += ifilNFT.power;
            }
        }
        return effectPower;
    }
    
    function getBuyLimitInfo(uint256 _prodid, address user) public view returns(uint256, uint256) {
        ProductInfo memory prod = dmexVendor.getProduct(_prodid);
        return (_maxBuyPowers[_prodid][user], prod.maxBuyPower.sub(_maxBuyPowers[_prodid][user]));
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
        if(ifilNFT.deleted) {
            return (0, 0);
        }
        
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
                _unreleaseBenefits += benefitPool.linearMineAmount.mul(linearReleaseDay.sub(diffDay)).mul(ifilNFT.power).div(linearReleaseDay).div(benefitPool.effectPower);
            }
        }
        return (_totalBenefits, _unreleaseBenefits);
    }
    
    function _calcDayBenefits(uint256 tokenid, uint256 _dayTime) private view returns(uint256) {
        IFilNFT memory ifilNFT = _ifilNfts[tokenid];
        if(ifilNFT.deleted) {
            return 0;
        }
        
        if (_dayTime < ifilNFT.activeTime || _dayTime >= ifilNFT.expireTime.add(linearReleaseDay.mul(DAYTIME))) {
            return 0;
        }
        
        uint256 _totalBenefits = 0;
        BenefitPool memory benefitPool = _beftPools[ifilNFT.prodid][_dayTime];
        if (_dayTime >= ifilNFT.activeTime && _dayTime < ifilNFT.expireTime && benefitPool.effectPower > 0) {
            _totalBenefits += benefitPool.fixedMineAmount.mul(ifilNFT.power).div(benefitPool.effectPower);
        }
        

        return _totalBenefits;
    }
    
    function _calcNFTBenefitsV2(uint256 _prodid, uint256 _power, uint256 _activeTime, uint256 _expireTime) private view returns(uint256, uint256) {
        uint256 endDayTime = block.timestamp.div(DAYTIME).mul(DAYTIME);
        if (endDayTime >= _expireTime) {
            endDayTime = _expireTime.sub(1);
        }
        uint256 _totalBenefits = 0;
        uint256 _unreleaseBenefits = 0;
        for (uint256 i = _activeTime; i <= endDayTime; i = i + DAYTIME) {
            BenefitPool memory benefitPool = _beftPools[_prodid][i];
            if (benefitPool.effectPower > 0) {
                _totalBenefits += benefitPool.fixedMineAmount.mul(_power).div(benefitPool.effectPower);
                
                uint256 diffDay = endDayTime.sub(i).div(DAYTIME);
                if (diffDay > 0 && diffDay > linearReleaseDay) {
                    diffDay = linearReleaseDay;
                }
                _unreleaseBenefits += benefitPool.linearMineAmount.mul(linearReleaseDay.sub(diffDay)).mul(_power).div(linearReleaseDay).div(benefitPool.effectPower);
            }
        }
        return (_totalBenefits, _unreleaseBenefits);
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