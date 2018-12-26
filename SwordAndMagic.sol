pragma solidity ^0.4.24;

contract SwordAndMagic {
    using SafeMath for *;
    using NameFilter for string;

    address public ga_CEO;
    uint256 public hurtRate = 1 ;
    uint256[3] internal glu_BaseHurt = [];
    uint256[3] internal glu_LvlAdd = [];
    uint256[130] internal glu_LvlExp = [] ;
    
    uint256 public gu_RID; 
    uint256 public gu_LastPID;

    mapping (address => uint256) public gd_Addr2PID;
    mapping (bytes32 => uint256) public gd_Name2PID;
    mapping (uint256 => SAMdatasets.Player) public gd_Player;
    mapping (uint256 => mapping (uint256 => SAMdatasets.PlayerRounds)) public gd_PlyrRnd;
    mapping (uint256 => mapping (uint256 => SAMdatasets.PlayerRank)) public gd_RndRankPlyr;
    mapping (uint256 => SAMdatasets.Round) public gd_RndData;
    mapping (uint256 => SAMdatasets.PotRound) public gd_SearchData;
    

    constructor()
        public
    {
        ga_CEO = msg.sender;
	}

    modifier IsPlayer() {
        address addr = msg.sender;
        uint256 codeLen;
        
        assembly {codeLen := extcodesize(addr)}
        require(codeLen == 0, "Not Human");
        _;
    }

    modifier CheckEthRange(uint256 eth) {
        require(eth >= 100000000000000 && eth <= 10000000000000000000, 
                "Out of Range");
        _;    
    }

    modifier CheckEthRange2(uint256 eth) {
        require(eth >= 50000000000000000 && eth <= 500000000000000000, 
                "Out of Range");
        _;    
    }

    function ModCEO(address newCEO) 
        IsPlayer() 
        public
    {
        require(address(0) != newCEO, "CEO Can not be 0");
        require(ga_CEO == msg.sender, "only ga_CEO can modify ga_CEO");
        ga_CEO = newCEO;
    }
    
    function GetAffID(uint256 pID, string affName, uint256 affID, address affAddr)
        internal
        returns(uint256)
    {
        uint256 aID;
        bytes32 name = affName.nameFilter() ;
        if (name != '' && name != gd_Player[pID].name)
        {
            aID = gd_Name2PID[name];
        } else if (affID != 0 && affID != pID){
            aID = affID;
        } else if (affAddr != address(0) && affAddr != msg.sender)
        {
            aID = gd_Addr2PID[affAddr];
        } else 
        {
            aID = gd_Player[pID].laff;
        }
        if (gd_Player[pID].laff != aID) 
        {
            gd_Player[pID].laff = aID;
        }
        return (aID) ;
    }

    function OnAttack(uint256 eth, string affName, uint256 affID, address affAddr)
        IsPlayer()
        CheckEthRange(eth.add(msg.value))
        public
        payable
    {
        uint256 pID = GetPIDXAddr(msg.sender);
        uint256 aID = GetAffID(pID, affName, affID, affAddr);
        Attack(pID, aID, eth);
    }

    function OnSearch()
        IsPlayer()
        CheckEthRange2(msg.value)
        public
        payable
    {
        uint256 pID = GetPIDXAddr(msg.sender);
        Search(pID);
    }

    function CheckGameState()
        public
    {
        if (now >= gd_RndData[gu_RID].end)
        {
            if (gd_RndData[gu_RID].state == 1)
            {
                PauseRound();
            }
            else if(gd_RndData[gu_RID].state == 2)
            {
                ResumeRound();
            }
            else if(gd_RndData[gu_RID].state == 3)
            {
                ActiveRound();
            }
        }
    }

    function UpdateVault(uint256 pID, uint256 lastRID)
        private 
    {
        uint256 unmaskWin = GetUnmaskWin(pID, lastRID);
        if (unmaskWin > 0)
        {
            gd_Player[pID].win = unmaskWin.add(gd_Player[pID].win);
            gd_PlyrRnd[pID][lastRID].win = unmaskWin.add(gd_PlyrRnd[pID][lastRID].win) ;
        }
        if(gu_RID != lastRID){
            if ((lastRID >> 16) == (gu_RID >> 16))
            {
                gd_PlyrRnd[pID][gu_RID].eth = gd_PlyrRnd[pID][lastRID].eth;
                gd_PlyrRnd[pID][gu_RID].win = gd_PlyrRnd[pID][lastRID].win;
                gd_PlyrRnd[pID][gu_RID].level = gd_PlyrRnd[pID][lastRID].level ;
                gd_PlyrRnd[pID][gu_RID].exp = gd_PlyrRnd[pID][lastRID].exp ;
            }
            gd_Player[pID].lrnd = gu_RID;
        }
    }

    function Withdraw()
        IsPlayer()
        public
    {
        uint256 pID = gd_Addr2PID[msg.sender];
        
        CheckGameState();
        UpdateVault(pID, gd_Player[pID].lrnd);
        
        if (gd_Player[pID].win > 0)
        {
            gd_Player[pID].addr.transfer(gd_Player[pID].win);
            gd_Player[pID].win = 0;
        }
    }

    function CheckName(string nameStr)
        IsPlayer()
        public
        view 
        returns(bool)
    {
        bytes32 name = nameStr.nameFilter();
        if (gd_Name2PID[name] == 0)
            return (true);
        else 
            return (false);
    }

    function ActiveRound()
        internal
    {
        uint256 oldRID = gu_RID ;
        uint256 mainRID = (gu_RID >> 16) ; 
        gu_RID = ((mainRID+1) << 16)+ 1 ;
        gd_RndData[gu_RID].strt = now;
        gd_RndData[gu_RID].end = now + 86400;
        gd_RndData[gu_RID].state = 1;
        gd_RndData[gu_RID].blood = ((3000000).add(((mainRID).mul(2000000)))).mul(1000000000000000000);
        gd_RndData[gu_RID].orig_blood = gd_RndData[gu_RID].blood;
        if (mainRID > 0) {
            gd_RndData[gu_RID].pot = gd_RndData[oldRID].pot;
            gd_RndData[gu_RID].pot2 = gd_RndData[oldRID].pot2;
        }
    }

    function TryActiveGame(uint256 pID)
        internal
        returns(bool)
    {
        if (pID >= 1 && gu_RID == 0)
        {
            ActiveRound();
            return (true);
        }
        return (false);
    }
  
    function RegisterName(string nameStr, string affName, uint256 affID, address affAddr)
        IsPlayer()
        public
        payable
    {
        require(msg.value >= 10 finney, "Lack of ETH");
        ga_CEO.transfer(msg.value);
        bytes32 name = nameStr.nameFilter();
        require(gd_Name2PID[name] == 0, "Name Already Exist");

        address addr = msg.sender;
        uint256 pID = GetPIDXAddr(addr);
        require(gd_Player[pID].name == '', "Have Registered");

        uint256 aID = GetAffID(pID, affName, affID, affAddr);
        gd_Player[pID].name = name;
        gd_Player[pID].laff = aID;
        gd_Name2PID[name] = pID;

        if(!TryActiveGame(pID))
        {
            CheckGameState();
        }
    }

    modifier CheckType(uint256 u_type) {
        require(u_type >= 0 && u_type <= 2, "Not Valid!"); 
        _;
    }

    function UpgradeXPay(uint256 u_type)
        IsPlayer()
        CheckType(u_type)
        public
        payable
    {
        uint256 pID = GetPIDXAddr(msg.sender);
        require(msg.value >= 10 finney, "Lack of ETH");
        gd_Player[pID].p_type = u_type;
        ga_CEO.transfer(msg.value);
        CheckGameState();
    }

    function GetAttackPrice()
        public 
        view 
        returns(uint256)
    {  
        if (gd_RndData[gu_RID].plyr != 0 && gd_RndData[gu_RID].state != 3)
        {
            return (CalcEthXKey((gd_RndData[gu_RID].keys2.add(1000000000000000000)), 1000000000000000000) );
        }
        else 
        {
            return ( 100000000000000 );
        }
    }
    
    function GetLeftTime()
        public
        view
        returns(uint256)
    {
        if (now < gd_RndData[gu_RID].end)
        {
            return( (gd_RndData[gu_RID].end).sub(now) );
        }
        return(0);
    }
    
    function GetCurRoundInfo()
        public
        view
        returns(uint256, uint256, uint256, uint256, uint256, bytes32, uint256, uint256)
    {
        uint256 rID = gu_RID;
        
        return
        (
            rID,
            gd_RndData[gu_RID].state,
            gd_RndData[rID].blood,
            gd_RndData[rID].pot,
            gd_RndData[rID].pot2,
            gd_Player[gd_RndData[rID].plyr].name,
            gd_SearchData[rID].pot,
            gd_RndData[rID].keys2
        );
    }
    
    function GetLastSearchInfo()
        public
        view
        returns (uint256, uint256, bytes32)
    {
        return (gd_SearchData[gu_RID-1].pot,
                gd_SearchData[gu_RID-1].p_cnt,
                gd_Player[gd_SearchData[gu_RID-1].plyr].name);
    }

    function GetPlayerInfoXAddr(address addr)
        public 
        view 
        returns(uint256, bytes32, uint256, uint256, uint256, uint256, 
                uint256, uint256, uint256, uint256, uint256)
    {
        if (addr == address(0))
        {
            addr == msg.sender;
        }
        uint256 pID = gd_Addr2PID[addr];
        uint256 unmask = GetUnmaskWin(pID, gd_Player[pID].lrnd) ;
        return
        (
            pID,
            gd_Player[pID].name,
            gd_Player[pID].win.add(unmask),
            gd_Player[pID].p_type,
            gd_PlyrRnd[pID][gu_RID].rank,
            gd_PlyrRnd[pID][gu_RID].keys,
            gd_PlyrRnd[pID][gu_RID].eth,
            gd_PlyrRnd[pID][gu_RID].win.add(GetUnmaskWin(pID, gu_RID)),
            gd_PlyrRnd[pID][gu_RID].exp,
            gd_PlyrRnd[pID][gu_RID].hurts,
            gd_SearchData[gu_RID].d_Eths[pID]
        );
    }

    function GetPlayerBalance(address addr)
        public
        view
        returns (uint256)
    {
        if (addr == address(0))
        {
            addr == msg.sender;
        }
        return (addr.balance);
    }

    function GetRoundRank(uint256 rID, uint256 rank)
        public
        view
        returns(uint256, bytes32, uint256, uint256, uint256)
    {
        uint256 pID = gd_RndRankPlyr[rID][rank].pID;
        return (
            pID,
            gd_Player[pID].name,
            gd_Player[pID].p_type,
            gd_PlyrRnd[pID][rID].exp,
            gd_RndRankPlyr[rID][rank].hurt
        );
    }

    function GetCurRoundRank(uint256 rank)
        public
        view
        returns(uint256, bytes32, uint256,uint256,uint256)
    {
        return GetRoundRank(gu_RID, rank);
    }

    function Attack(uint256 pID, uint256 affID, uint256 eth)
        private
    {
        CheckGameState();
        UpdateVault(pID, gd_Player[pID].lrnd);
        if (gd_RndData[gu_RID].state == 1)
        {
            gd_Player[pID].win = gd_Player[pID].win.sub(eth);
            AttackCore(pID, affID, eth.add(msg.value));    
        } 
        else 
        {   
            gd_Player[pID].win = gd_Player[pID].win.add(msg.value);
        }
    }

    function Search(uint256 pID)
        private
    {
        CheckGameState();
        UpdateVault(pID, gd_Player[pID].lrnd);
        
        if(gd_RndData[gu_RID].state == 2) {
            uint256 eth_in = gd_SearchData[gu_RID].d_Eths[pID];
            if (eth_in == 0) {
                gd_SearchData[gu_RID].d_PIDs[gd_SearchData[gu_RID].p_cnt] = pID;
                gd_SearchData[gu_RID].p_cnt ++ ;
            }
            uint256 eth_now = msg.value ;
            if (eth_in.add(eth_now) > 500000000000000000) {
                eth_now = 500000000000000000-eth_in;
                gd_Player[pID].win = gd_Player[pID].win.add(msg.value.sub(eth_now));
            }
            gd_SearchData[gu_RID].d_Eths[pID] = eth_now.add(gd_SearchData[gu_RID].d_Eths[pID]) ;
            gd_PlyrRnd[pID][gu_RID].eth = eth_now.add(gd_PlyrRnd[pID][gu_RID].eth);
            uint256 pot2 = eth_now.mul(60)/100;
            gd_RndData[gu_RID].pot2 = gd_RndData[gu_RID].pot2.add(pot2);
            uint256 pot = eth_now.mul(35)/100;
            gd_RndData[gu_RID].pot = gd_RndData[gu_RID].pot.add(pot);
            uint256 comfee = eth_now.sub(pot).sub(pot2);
            ga_CEO.transfer(comfee);
            gd_SearchData[gu_RID].pot = gd_SearchData[gu_RID].pot.add(eth_now);
        }else{
            gd_Player[pID].win = gd_Player[pID].win.add(msg.value);
        }
    }
    
    function UpdRankXExp(uint256 pID)
        private
    {
        uint256 i = 1;
        uint256 j = 0;
        uint256 orig_i = 20;
        for(i = 1 ; i <= 10 && gd_RndRankPlyr[gu_RID][i].hurt > 0 ; i ++)
        {
            if (gd_RndRankPlyr[gu_RID][i].pID == pID)
            {
                orig_i = i;
                break;
            }
        }
        if (orig_i > 15)
        {
            for(i = 1 ; i <= 10; i ++)
            {
                if (gd_RndRankPlyr[gu_RID][i].hurt == 0)
                {
                    gd_RndRankPlyr[gu_RID][i].pID = pID;
                    gd_RndRankPlyr[gu_RID][i].hurt = gd_PlyrRnd[pID][gu_RID].hurts;
                    gd_PlyrRnd[pID][gu_RID].rank = i;
                    break;
                }
                if (gd_PlyrRnd[pID][gu_RID].hurts > gd_RndRankPlyr[gu_RID][i].hurt)
                {
                    for(j = 10 ; j > i ; j --)
                    {
                        gd_RndRankPlyr[gu_RID][j].pID = gd_RndRankPlyr[gu_RID][j-1].pID;
                        gd_RndRankPlyr[gu_RID][j].hurt = gd_RndRankPlyr[gu_RID][j-1].hurt;
                        gd_PlyrRnd[gd_RndRankPlyr[gu_RID][j].pID][gu_RID].rank = j;
                    }
                    gd_RndRankPlyr[gu_RID][i].pID = pID;
                    gd_RndRankPlyr[gu_RID][i].hurt = gd_PlyrRnd[pID][gu_RID].hurts;
                    gd_PlyrRnd[pID][gu_RID].rank = i;
                    break;
                }
            }
        }
        else
        {   
            gd_RndRankPlyr[gu_RID][orig_i].hurt = gd_PlyrRnd[pID][gu_RID].hurts;
            if (orig_i == 1 || (orig_i > 1 && gd_RndRankPlyr[gu_RID][orig_i].hurt < gd_RndRankPlyr[gu_RID][orig_i-1].hurt))
            {
                return;
            }
            for(i = orig_i-1 ; i > 0; i --){
                if (gd_RndRankPlyr[gu_RID][orig_i].hurt < gd_RndRankPlyr[gu_RID][i].hurt)
                {
                    for(j = orig_i; j > i+1 ; j --)
                    {
                        gd_RndRankPlyr[gu_RID][j].pID = gd_RndRankPlyr[gu_RID][j-1].pID;
                        gd_RndRankPlyr[gu_RID][j].hurt = gd_RndRankPlyr[gu_RID][j-1].hurt;
                        gd_PlyrRnd[gd_RndRankPlyr[gu_RID][j].pID][gu_RID].rank = j;
                    }
                    gd_RndRankPlyr[gu_RID][i+1].pID = pID;
                    gd_RndRankPlyr[gu_RID][i+1].hurt = gd_PlyrRnd[pID][gu_RID].hurts;
                    gd_PlyrRnd[pID][gu_RID].rank = i+1;
                    return;
                }
            }
            for(j = orig_i; j > 1 ; j --)
            {
                gd_RndRankPlyr[gu_RID][j].pID = gd_RndRankPlyr[gu_RID][j-1].pID;
                gd_RndRankPlyr[gu_RID][j].hurt = gd_RndRankPlyr[gu_RID][j-1].hurt;
                gd_PlyrRnd[gd_RndRankPlyr[gu_RID][j].pID][gu_RID].rank = j;
            }
            gd_RndRankPlyr[gu_RID][1].pID = pID;
            gd_RndRankPlyr[gu_RID][1].hurt = gd_PlyrRnd[pID][gu_RID].hurts;
            gd_PlyrRnd[pID][gu_RID].rank = 1;
            return;
        }
    }

    function UpdLevel(uint256 pID)
        private
    {
        uint256 i = 0;
        if (gd_PlyrRnd[pID][gu_RID].exp >= glu_LvlExp[129])
        {
            gd_PlyrRnd[pID][gu_RID].level = 129;
        }
        else
        {
            for ( i = gd_PlyrRnd[pID][gu_RID].level+1; i < 130; i ++)
            {
                if (gd_PlyrRnd[pID][gu_RID].exp < glu_LvlExp[i])
                {
                    break;
                }
            }
            gd_PlyrRnd[pID][gu_RID].level = i-1;
        }
    }

    function AttackCore(uint256 pID, uint256 affID, uint256 eth)
        private
    {
        if (eth > 1000000000) 
        {
            uint256 keys = CalcKeyXEth((gd_RndData[gu_RID].eth), eth);
            if (keys >= 1000000000000000000)
            {
                if (gd_RndData[gu_RID].plyr != pID)
                {
                    gd_RndData[gu_RID].plyr = pID; 
                }
            }
            uint256 comfee = eth / 50;
            ga_CEO.transfer(comfee);

            uint256 gen ;
            uint256 pot ;
            if (gd_Player[pID].p_type == 0) {
                gen = eth.mul(58)/100;
                pot = eth/10;
            }else if(gd_Player[pID].p_type == 1){
                gen = eth.mul(45)/100;
                pot = eth.mul(8)/100;
            }else {
                gen = eth.mul(30)/100;
                pot = eth.mul(8)/100;
            }
            gd_RndData[gu_RID].pot2 = pot.add(gd_RndData[gu_RID].pot2);
            pot = eth.sub(comfee).sub(gen).sub(pot);

            if (gd_Player[affID].name != '')
            {
                uint256 affFee = eth / 10 ;
                gd_Player[affID].win = affFee.add(gd_Player[affID].win);
                gd_PlyrRnd[affID][gu_RID].win = affFee.add(gd_PlyrRnd[affID][gu_RID].win) ;
                pot = pot.sub(affFee);
            }

            uint256 hurt = (keys).mul((glu_BaseHurt[gd_Player[pID].p_type]+gd_PlyrRnd[pID][gu_RID].level.mul(glu_LvlAdd[gd_Player[pID].p_type])));
            if (hurtRate > 1){
                hurt = hurt.mul(hurtRate) ;
            }
            uint256 exp = hurt/10000000000000000000;
            gd_PlyrRnd[pID][gu_RID].exp = gd_PlyrRnd[pID][gu_RID].exp.add(exp);
            UpdLevel(pID);
            
            gd_PlyrRnd[pID][gu_RID].keys = keys.add(gd_PlyrRnd[pID][gu_RID].keys);
            gd_PlyrRnd[pID][gu_RID].eth = eth.add(gd_PlyrRnd[pID][gu_RID].eth);
            gd_PlyrRnd[pID][gu_RID].hurts = hurt.add(gd_PlyrRnd[pID][gu_RID].hurts);
            UpdRankXExp(pID);
			
            gd_RndData[gu_RID].eth = eth.add(gd_RndData[gu_RID].eth);
            
            gd_RndData[gu_RID].keys = keys.add(gd_RndData[gu_RID].keys);
            gd_RndData[gu_RID].keys2 = keys.add(gd_RndData[gu_RID].keys2);
            gd_RndData[gu_RID].hurts = hurt.add(gd_RndData[gu_RID].hurts);
            uint256 dust = UpdateMask(gu_RID, pID, gen, hurt);
            gd_RndData[gu_RID].pot = pot.add(dust).add(gd_RndData[gu_RID].pot);
            
            
            if (hurt < gd_RndData[gu_RID].blood)
            {
                gd_RndData[gu_RID].blood = gd_RndData[gu_RID].blood.sub(hurt);
            }
            else
            {
                EndRound();
            }
        }else
        {
            gd_Player[pID].win = gd_Player[pID].win.add(eth);
        }
    }
	
    function GetKeyXEth(uint256 rID, uint256 eth)
        public
        view
        returns(uint256)
    {
        if (gd_RndData[rID].plyr != 0 && gd_RndData[rID].state != 3)
        {
            return ( CalcKeyXEth((gd_RndData[rID].eth), eth) );
        }
        else
        {
            return ( CalcKeys(eth) );
        }
    }
    
    function GetEthXKey(uint256 keys)
        public
        view
        returns(uint256)
    {
        uint256 rID = gu_RID;
        if (gd_RndData[rID].state != 3)
        {
            return ( CalcEthXKey((gd_RndData[rID].keys2.add(keys)), keys) );
        }
        else 
        {
            return ( CalcEth(keys) );
        }
    }

    function GetPIDXAddr(address addr)
        private
        returns (uint256)
    {
        uint256 pID = gd_Addr2PID[addr];
        if ( pID == 0)
        {
            gu_LastPID++;
            gd_Addr2PID[addr] = gu_LastPID;
            gd_Player[gu_LastPID].addr = addr;
            return (gu_LastPID);
        } else {
            return (pID);
        }
    }

    function AddLastHurt(uint256 rPID, uint256 hurt)
        private
    {
        gd_PlyrRnd[rPID][gu_RID].hurts = gd_PlyrRnd[rPID][gu_RID].hurts.add(hurt);
        gd_PlyrRnd[rPID][gu_RID].hurts2 = gd_PlyrRnd[rPID][gu_RID].hurts2.add(hurt);
        gd_RndData[gu_RID].hurts = gd_RndData[gu_RID].hurts.add(hurt);
    }

    function AddHurtXRank(uint256 r)
        private
        returns(uint256)
    {
        uint256 rPID = gd_RndRankPlyr[gu_RID][r].pID;
        uint256 hurts = 0 ;
        if (r == 1)
        {
            if (gd_PlyrRnd[rPID][gu_RID].level >= 98)
            {
                hurts = 1000000000000000000000000;
            }
            else if(gd_PlyrRnd[rPID][gu_RID].level >= 59)
            {
                hurts = 200000000000000000000000;
            }
            else if(gd_PlyrRnd[rPID][gu_RID].level >= 29)
            {
                hurts = 100000000000000000000000 ;
                
            }
        }
        else if(r > 1 && r <= 5)
        {
            if(gd_PlyrRnd[rPID][gu_RID].level >= 59)
            {
                hurts = 200000000000000000000000;
            }
            else if(gd_PlyrRnd[rPID][gu_RID].level >= 29)
            {
                hurts = 100000000000000000000000;
            }
        }
        else 
        {
            if(gd_PlyrRnd[rPID][gu_RID].level >= 29)
            {
                hurts = 100000000000000000000000;
            }
        }
        if (hurts > 0)
        {
            AddLastHurt(rPID, hurts);
        }
        return hurts;
    }
    
    function EndRound()
        private
    {
        uint256 lastPID = gd_RndData[gu_RID].plyr;
        gd_RndData[gu_RID].state = 3;
        gd_RndData[gu_RID].strt = now;
        gd_RndData[gu_RID].end = now+1800;
        
        gd_RndData[gu_RID].blood = 0;

        AddLastHurt(lastPID, gd_RndData[gu_RID].orig_blood.mul(40)/100);
        bool isLastInRank = false;
        uint256 i = 0;
        for(i = 1 ; i <= 10 ; i ++)
        {
            if (gd_RndRankPlyr[gu_RID][i].hurt == 0)
            {
                break;
            }
            AddHurtXRank(i);
            if (isLastInRank == false && gd_RndRankPlyr[gu_RID][i].pID == lastPID){
                isLastInRank = true;
            }
        }
         
        uint256 lastGen ;
        if (gd_Player[lastPID].p_type == 0)
        {
            lastGen = gd_RndData[gu_RID].pot.mul(90)/100;
        }
        else if (gd_Player[lastPID].p_type == 1)
        {
            lastGen = gd_RndData[gu_RID].pot.mul(85)/100;
        }
        else{
            lastGen = gd_RndData[gu_RID].pot.mul(80)/100;
        }
        uint256 ppt = lastGen.mul(1000000000000000000)/gd_RndData[gu_RID].hurts;
        uint256 pearn = 0 ;
        uint256 tPID = 0;
        for(i = 1 ; i < 10 ; i ++)
        {
            if (gd_RndRankPlyr[gu_RID][i].hurt == 0)
            {
                break;
            }
            tPID = gd_RndRankPlyr[gu_RID][i].pID ;
            pearn = ppt.mul(gd_PlyrRnd[tPID][gu_RID].hurts2)/(1000000000000000000);
        }
        if (!isLastInRank) {
            pearn = ppt.mul(gd_PlyrRnd[lastPID][gu_RID].hurts2)/(1000000000000000000);
        }
        uint256 dust = lastGen.sub((ppt.mul(gd_RndData[gu_RID].hurts)) / (1000000000000000000)) ;
        gd_RndData[gu_RID].pot = (gd_RndData[gu_RID].pot.add(dust)).sub(lastGen);
    }

    function PauseRound()
        private
    {
        gd_RndData[gu_RID].strt = now;
        gd_RndData[gu_RID].end = gd_RndData[gu_RID].strt+7200 ;
        gd_RndData[gu_RID].state = 2;
        if (gd_RndData[gu_RID].hurts > 0)
        {
            uint256 lastGen = gd_RndData[gu_RID].pot.mul(30)/100;
            uint256 ppt = lastGen.mul(1000000000000000000)/gd_RndData[gu_RID].hurts;
            uint256 dust = lastGen.sub((ppt.mul(gd_RndData[gu_RID].hurts)) / 1000000000000000000);
            gd_RndData[gu_RID].pot = (gd_RndData[gu_RID].pot.add(dust)).sub(lastGen);
        }
    }

    function ResumeRound()
        private
    {
        uint256 addBlood = 0;
        if (gd_SearchData[gu_RID].pot > 0)
        {
            if (gd_SearchData[gu_RID].pot <= 500000000000000000)
            {
                addBlood = (gd_RndData[gu_RID].orig_blood.sub(gd_RndData[gu_RID].blood)).mul(70)/100;
            } else if(gd_SearchData[gu_RID].pot <= 1000000000000000000) {
                addBlood = (gd_RndData[gu_RID].orig_blood.sub(gd_RndData[gu_RID].blood)).mul(40)/100;
            } else if(gd_SearchData[gu_RID].pot <= 5000000000000000000)
            {
                addBlood = (gd_RndData[gu_RID].orig_blood.sub(gd_RndData[gu_RID].blood))/10;
            }

            uint i = 0 ; 
            uint pID = 0 ;
            uint t_weight = 0;
             
            for( i = 0 ; i < gd_SearchData[gu_RID].p_cnt ; i ++)
            {
                pID = gd_SearchData[gu_RID].d_PIDs[i] ;
                gd_SearchData[gu_RID].d_Weight[pID] = gd_SearchData[gu_RID].d_Eths[pID]/500000000000000 ;
                t_weight = t_weight.add(gd_SearchData[gu_RID].d_Weight[pID]) ;
            }
            uint mul_rate = 1000000000000000000/t_weight;
            uint256 seed = uint256(keccak256(abi.encodePacked(
                (block.timestamp).add
                (block.difficulty).add
                ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
                (block.gaslimit).add
                ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)).add
                (block.number)
                )));
            uint256 randv = seed % 1000000000000000000 ;
            for ( i = 0 ; i < gd_SearchData[gu_RID].p_cnt ; i ++)
            {
                pID = gd_SearchData[gu_RID].d_PIDs[i] ;
                if (randv > gd_SearchData[gu_RID].d_Weight[pID].mul(mul_rate)){
                    randv = randv.sub(gd_SearchData[gu_RID].d_Weight[pID].mul(mul_rate)) ;
                }else{
                    break;
                }
            } 
            gd_SearchData[gu_RID].plyr = pID ;
            uint256 potwin = gd_RndData[gu_RID].pot2.mul(60)/100 ;
            gd_Player[pID].win = gd_Player[pID].win.add(potwin) ;
            gd_PlyrRnd[pID][gu_RID].win = potwin.add(gd_PlyrRnd[pID][gu_RID].win) ;
            uint256 gen2 = gd_RndData[gu_RID].pot2.sub(potwin) ;
            mul_rate = gen2/t_weight ;
            gd_RndData[gu_RID].pot2 = gen2.sub(mul_rate.mul(t_weight)) ;
            for (i = 0 ; i < gd_SearchData[gu_RID].p_cnt ; i ++)
            {
                pID = gd_SearchData[gu_RID].d_PIDs[i] ;
                randv = mul_rate.mul(gd_SearchData[gu_RID].d_Weight[pID]);
                gd_Player[pID].win = gd_Player[pID].win.add(randv) ;
                gd_PlyrRnd[pID][gu_RID].win = randv.add(gd_PlyrRnd[pID][gu_RID].win) ;
            }
            
        }

        uint256 oldRID = gu_RID;
        gu_RID ++ ;
        gd_RndData[gu_RID].state = 1;
        gd_RndData[gu_RID].strt = now ;
        gd_RndData[gu_RID].end = now+86400 ;
        gd_RndData[gu_RID].orig_blood = gd_RndData[oldRID].orig_blood ;
        gd_RndData[gu_RID].blood = addBlood.add(gd_RndData[oldRID].blood);
        gd_RndData[gu_RID].keys2 = gd_RndData[oldRID].keys2 ;
        gd_RndData[gu_RID].eth = gd_RndData[oldRID].eth ;
        gd_RndData[gu_RID].pot = gd_RndData[oldRID].pot ;
        gd_RndData[gu_RID].pot2 = gd_RndData[oldRID].pot2 ;
        /*
        for( i = 1 ; i <= 10 ; i ++){
            gd_RndRankPlyr[gu_RID][i].pID = gd_RndRankPlyr[oldRID][i].pID ;
            gd_RndRankPlyr[gu_RID][i].hurt = gd_RndRankPlyr[oldRID][i].hurt;
        }
        */
    }
}

library SAMdatasets {
    struct Player {
        address addr;
        bytes32 name;
        uint256 p_type;
        uint256 win;
        uint256 laff;
        uint256 lrnd;
    }
    struct PlayerRounds {
        uint256 eth;
        uint256 win;
        uint256 keys;
        uint256 hurts;
        uint256 hurts2;
        uint256 level;
        uint256 exp;
        uint256 rank;
    }
    struct PlayerRank {
        uint256 pID;
        uint256 hurt;
    }

    struct Round {
        uint256 state;
        uint256 strt;
        uint256 end;
        uint256 orig_blood;
        uint256 blood;
        uint256 keys;
        uint256 keys2;
        uint256 hurts;
        uint256 eth;
        uint256 pot;
        uint256 pot2;
        uint256 plyr;
    }
    struct PotRound {
        uint256 pot;
        uint256 p_cnt;
        uint256 plyr;
        mapping (uint256 => uint256) d_PIDs;
        mapping (uint256 => uint256) d_Eths ;
        mapping (uint256 => uint256) d_Weight ;
    }
}

library NameFilter {
    function nameFilter(string _input)
        internal
        pure
        returns(bytes32)
    {
        bytes memory _temp = bytes(_input);
        uint256 _length = _temp.length;
        
        require (_length <= 32 && _length > 0, "Invalid Length");
        require(_temp[0] != 0x20 && _temp[_length-1] != 0x20, "Can NOT start with SPACE");
        if (_temp[0] == 0x30)
        {
            require(_temp[1] != 0x78, "CAN NOT Start With 0x");
            require(_temp[1] != 0x58, "CAN NOT Start With 0X");
        }
        
        bool _hasNonNumber;
        
        for (uint256 i = 0; i < _length; i++)
        {
            if (_temp[i] > 0x40 && _temp[i] < 0x5b)
            {
                _temp[i] = byte(uint(_temp[i]) + 32);
                if (_hasNonNumber == false)
                {
                    _hasNonNumber = true;
                }
            } else {
                require
                (
                    _temp[i] == 0x20 || 
                    (_temp[i] > 0x60 && _temp[i] < 0x7b) ||
                    (_temp[i] > 0x2f && _temp[i] < 0x3a),
                    "Include Illegal Characters!"
                );
                if (_temp[i] == 0x20)
                {
                    require( _temp[i+1] != 0x20, "ONLY One Space Allowed");
                }
                
                if (_hasNonNumber == false && (_temp[i] < 0x30 || _temp[i] > 0x39))
                {
                    _hasNonNumber = true; 
                }  
            }
        }
        
        require(_hasNonNumber == true, "All Numbers Not Allowed");
        
        bytes32 _ret;
        assembly {
            _ret := mload(add(_temp, 32))
        }
        return (_ret);
    }
}

library SafeMath {
    function mul(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256 c) 
    {
        if (a == 0) 
        {
            return 0;
        }
        c = a * b;
        require(c / a == b, "Mul Failed");
        return c;
    }
    function sub(uint256 a, uint256 b)
        internal
        pure
        returns (uint256) 
    {
        require(b <= a, "Sub Failed");
        return a - b;
    }

    function add(uint256 a, uint256 b)
        internal
        pure
        returns (uint256 c) 
    {
        c = a + b;
        require(c >= a, "Add Failed");
        return c;
    }
    
    function sqrt(uint256 x)
        internal
        pure
        returns (uint256 y) 
    {
        uint256 z = ((add(x,1)) / 2);
        y = x;
        while (z < y) 
        {
            y = z;
            z = ((add((x / z),z)) / 2);
        }
    }
    function sq(uint256 x)
        internal
        pure
        returns (uint256)
    {
        return (mul(x,x));
    }
}