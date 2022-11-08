//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * ██╗███╗   ██╗████████╗███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗███████╗██████╗ 
 * ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║██╔════╝██╔══██╗
 * ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║█████╗  ██║  ██║
 * ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║██╔══╝  ██║  ██║
 * ██║██║ ╚████║   ██║   ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║███████╗██████╔╝
 * ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝╚═════╝ 
 */

import "./stackPool.sol";
/**
 * Interchained STACK_deus aka "STACK" v2
 * DAO-STACK-V2 Smart Contract
 */
contract DAO_STACK is IERC20, Auth {

    IERC20 token = IERC20(address(this));
    /**
     * address  
     */
    address payable public _governor = payable(0x050134fd4EA6547846EdE4C4Bf46A334B7e87cCD);
    address payable public _community = payable(0x987576AEc36187887FC62A19cb3606eFfA8B4023);
    address private rebateOracleAddress;
    address payable public STACKPOOL;
    
    /**
     * strings  
     */
    string constant _name = "KEK STACK DAO";
    string constant _symbol = "STACK-KEK";

    /**
     * integers
     */
    uint8 constant _decimals = 18;
    uint256 internal immutable bp = 10000;
    uint256 internal taxFeeInBasis = 300;
    uint256 internal devFeeInBasis = 700;
    uint256 private _totalSupply;

    uint public genesis;
    uint256 public launchedAt;
    uint256 private startTime; 

    uint256 public totalEtherFees;
    uint256 public totalTokenFees;
    uint256 public totalTokenBurn;
    uint256 public totalEtherStacked;
    uint256 public totalTokenStacked;
    
    uint256 private constant DEV_FEE = 1000;
    uint256 private constant PERCENT_DIVIDER = 10000;

    uint256 private constant TIME_TO_UNSTACK = 1 minutes;
    // uint256 private constant TIME_TO_UNSTACK = 24 hours;
    uint256 private constant TIME_TO_CLAIM = 1 minutes;
    // uint256 private constant TIME_TO_CLAIM = 24 hours;

    uint256 private constant GENERAL_CLASS = 10000 ether;    
    uint256 private GENERAL_REBATE_SHARDS = 2*10**17; // 2
    uint256 private constant LOWR_CLASS = 50000 ether;    
    uint256 private LOWR_REBATE_SHARDS = 3*10**18; // 3
    uint256 private constant MIDL_CLASS = 100000 ether;    
    uint256 private MIDL_REBATE_SHARDS = 5*10**18; // 5
    uint256 private constant UPPR_CLASS = 1000000 ether; 
    uint256 private UPPR_REBATE_SHARDS = 7*10**18; // 7
    uint256 private constant VIP_CLASS = 10000000 ether;  
    uint256 private VIP_REBATE_SHARDS = 10*10**18; // 10
    
    /**
     * mappings  
     */
    mapping(address => uint256) public _balances;
    mapping(address => mapping (address => uint256)) public _allowances;
    mapping(address => User) private users;
    
    /**
     * structs  
     */
    struct Stacking {
        uint256 totalStacked; 
        uint256 lastStackTime;    
        uint256 totalClaimed;
        uint256 lastClaimed; 
        uint256 tier;
    }
    
    struct User {
        Stacking sNative;
        Stacking sToken;
    }

    /**
     * bools  
     */
    bool internal initialized;
    bool public launched = false; 
    /**
     * Events  
     */
    event Launched(uint256 launchedAt);
    event Deposit(address indexed dst, uint256 amount);
    event Stack(address indexed dst, uint256 ethAmount, uint256 eFee, uint256 tokenAmount, uint256 tFee);
    event Mint(address indexed dst, uint256 minted);
    event Burn(address indexed zeroAddress, uint256 burned);
    event Withdrawal(address indexed src, uint256 ethAmount, uint256 tokenAmount, address indexed zeroAddress, uint256 burnFee);
    event ClaimNative(address indexed src, uint256 ethAmount, address indexed ethFeeAddress, uint256 eFee);
    event Received(address, uint256);
    event ReceivedFallback(address, uint256);

    /**
     * Function modifiers 
     */
    modifier onlyGovernor() virtual {
        require(isGovernor(_msgSender()), "!GOVERNOR"); _;
    }

    constructor(address rebateOracle) Auth(_msgSender(),_community,_governor) {
        genesis = block.number;
        initialize(_governor,_community,rebateOracle); 
        STACKPOOL = payable(new STACK_POOL());
        emit Transfer(address(0), address(this), _totalSupply);
    }

    fallback() external payable { 
        stackNativeCoin(uint(msg.value));
    }
    
    receive() external payable {
        stackNativeCoin(uint(msg.value));
     }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure returns (uint8) { return _decimals; }
    function symbol() external pure returns (string memory) { return _symbol; }
    function name() external pure returns (string memory) { return _name; }
    function getOwner() external view returns (address) { return Governor(); }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function _mint(address account, uint256 amount) private {
        require(safeAddr(address(account)) != false, "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) private {
        require(safeAddr(address(account)) != false, "ERC20: burn from the zero address");
        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
    
    function Governor() public view returns (address) {
        return address(_governor);
    }

    function isGovernor(address account) public view returns (bool) {
        if(address(account) == address(_governor)){
            return true;
        } else {
            return false;
        }
    }

    function initialize(address payable governance,address payable community,address rebateOracle) private {
        require(initialized == false);
        _governor = payable(governance);
        _community = payable(community);
        rebateOracleAddress = rebateOracle;
        startTime = block.timestamp + 1 minutes;
        Auth.authorize(address(governance));
        Auth.authorize(address(community));
        Auth.authorize(address(rebateOracle));
        _mint(_msgSender(), 1*10**18); 
        initialized = true;
    }

    function launch() public authorized() {
        require(launched == false,"Already launched!");        
        launchedAt = block.timestamp;
        launched = true;
        emit Launched(launchedAt);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        require(safeAddr(address(spender)) != false, "ERC20: approve from the zero address");
        _allowances[_msgSender()][spender] = amount;
        emit Approval(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns(bool) {
        return _transfer(_msgSender(), recipient, amount, true);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns(bool) {
        address caller = _msgSender();
        if(address(caller) != address(sender)){
            require(uint256(_allowances[sender][_msgSender()]) >= uint256(amount),"Insufficient Allowance!");
            _allowances[sender][_msgSender()] = _allowances[sender][_msgSender()] - amount;
        }
        return _transfer(sender, recipient, amount, true);
    }
    
    function _transfer(address sender, address recipient, uint256 amount, bool takeFee) internal returns(bool) {
        require(safeAddr(address(sender)) != false, "ERC20: transfer from the zero address");
        if(takeFee == true) {
            uint256 cFee = (uint256(amount) * uint256(taxFeeInBasis)) / uint256(bp);
            uint256 dFee = (uint256(amount) * uint256(devFeeInBasis)) / uint256(bp);
            _balances[sender] = _balances[sender] - amount;
            amount -= cFee;
            amount -= dFee;
            _balances[recipient] = _balances[recipient] + amount;
            _balances[_community] = _balances[_community] + cFee;
            _balances[_governor] = _balances[_governor] + dFee;
            emit Transfer(sender, recipient, amount);
            emit Transfer(sender, _community, cFee);
            emit Transfer(sender, _governor, dFee);
        } else {
            _balances[sender] = _balances[sender] - amount;
            _balances[recipient] = _balances[recipient] + amount;
            emit Transfer(sender, recipient, amount);
        }
        return true;
    }
    
    function safeAddr(address wallet_) public pure returns (bool)   {
        if(uint160(address(wallet_)) > 0) {
            return true;
        } else {
            return false;
        }   
    }

    function setRebateOracle(address rebateOracle) public authorized() {
        rebateOracleAddress = address(rebateOracle);
    }

    function setStackPool(address payable stackPool) public authorized() {
        STACKPOOL = stackPool;
    }
    
    function setRebateAmount(uint256 rebateAmount, uint256 class) public onlyGovernor() {
        require(uint256(class) > uint256(0));
        if(uint256(class) == uint256(1)){
            GENERAL_REBATE_SHARDS = uint256(rebateAmount);
        } else if(uint256(class) == uint256(2)){
            LOWR_REBATE_SHARDS = uint256(rebateAmount);
        } else if(uint256(class) == uint256(3)){
            MIDL_REBATE_SHARDS = uint256(rebateAmount);
        } else if(uint256(class) == uint256(4)){
            UPPR_REBATE_SHARDS = uint256(rebateAmount);
        } else if(uint256(class) == uint256(5)){
            VIP_REBATE_SHARDS = uint256(rebateAmount);
        }
    }

    function checkMyStacks() public view returns(uint,uint,uint,uint) {
        User storage user = users[_msgSender()];
        uint lastStacked = user.sNative.lastStackTime;
        uint amountStacked = user.sNative.totalStacked;
        uint tES = totalEtherStacked; 
        uint tEF = totalEtherFees;
        return(lastStacked,amountStacked,tES,tEF);
    }

    function checkStacks(address usersWallet) public view returns(uint,uint,uint,uint) {
        User storage user = users[usersWallet];
        uint lastStacked = user.sNative.lastStackTime;
        uint amountStacked = user.sNative.totalStacked;
        uint tES = totalEtherStacked; 
        uint tEF = totalEtherFees;
        return(lastStacked,amountStacked,tES,tEF);
    }

    function stackNativeCoin(uint amountStack) public payable {
        User storage user = users[_msgSender()];
        uint256 ethAmount = msg.value;
        require(launched == true,"Not Launched");
        require(uint(amountStack) == uint(ethAmount),"Stack invalid");
        require(safeAddr(address(rebateOracleAddress)) != false,"Not enabled");
        uint256 eFee = (ethAmount * DEV_FEE) / PERCENT_DIVIDER;
        require(uint256(ethAmount) > uint256(0),"Zero dissallowed");
        if(address(_msgSender()) == address(rebateOracleAddress)){
            emit Deposit(_msgSender(), msg.value);
            return;
        } else {
            require(uint256(ethAmount) >= uint256(GENERAL_CLASS),"Not enough ether to enter tier");
            if(uint256(ethAmount) >= uint256(GENERAL_CLASS) && uint256(ethAmount) < uint256(LOWR_CLASS)) {
                user.sNative.tier = 1;
            } else if(uint256(ethAmount) >= uint256(LOWR_CLASS) && uint256(ethAmount) < uint256(MIDL_CLASS)) {
                user.sNative.tier = 2;
            } else if(uint256(ethAmount) >= uint256(MIDL_CLASS) && uint256(ethAmount) < uint256(UPPR_CLASS)) {
                user.sNative.tier = 3;
            } else if(uint256(ethAmount) >= uint256(UPPR_CLASS) && uint256(ethAmount) < uint256(VIP_CLASS)) {
                user.sNative.tier = 4;
            } else if(uint256(ethAmount) >= uint256(VIP_CLASS)) {
                user.sNative.tier = 5;
            }
            ethAmount -= eFee;
            user.sNative.lastStackTime = block.timestamp;
            user.sNative.totalStacked += ethAmount;
            totalEtherStacked += ethAmount; 
            totalEtherFees += eFee;
            uint cFee = eFee/2;
            uint dFee = eFee-cFee;
            payable(address(STACKPOOL)).transfer(uint256(ethAmount));
            payable(address(_community)).transfer(uint256(cFee));
            payable(address(_governor)).transfer(uint256(dFee));
            _mint(_msgSender(), ethAmount);
    	    emit Mint(_msgSender(), ethAmount);
            emit Deposit(_msgSender(), msg.value);
        }
    } 

    function claimNative() public {
        require(launched == true,"Not Launched");
        User storage user = users[_msgSender()];
        require(block.timestamp > user.sNative.lastClaimed + TIME_TO_CLAIM, "Claim not available yet");
        uint256 ethAmount = user.sNative.totalStacked;
        require(uint256(ethAmount) > uint256(0),"Can't claim with 0 ether");
        uint256 ethPool = address(this).balance;
        uint256 ETHER_REBATE_AMOUNT;
        require(uint256(user.sNative.tier) >= uint256(1));
        if(uint256(user.sNative.tier) == uint256(1)) {
            ETHER_REBATE_AMOUNT = uint256(GENERAL_REBATE_SHARDS);
        } else if(uint256(user.sNative.tier) == uint256(2)) {
            ETHER_REBATE_AMOUNT = uint256(LOWR_REBATE_SHARDS);
        } else if(uint256(user.sNative.tier) == uint256(3)) {
            ETHER_REBATE_AMOUNT = uint256(MIDL_REBATE_SHARDS);
        } else if(uint256(user.sNative.tier) == uint256(4)) {
            ETHER_REBATE_AMOUNT = uint256(UPPR_REBATE_SHARDS);
        } else if(uint256(user.sNative.tier) == uint256(5)) {
            ETHER_REBATE_AMOUNT = uint256(VIP_REBATE_SHARDS);
        } else {
            revert("Hmm, please try again");
        }
        require(uint256(ethPool) > uint256(ETHER_REBATE_AMOUNT),"Unstatisfactory ether pool supply");
        if(uint256(address(this).balance) < uint256(ETHER_REBATE_AMOUNT)){
            revert("Not enough ether to cover stack rebate, operators must refill more ether for rebates in pool");
        }
	    uint256 eFee = (ETHER_REBATE_AMOUNT * DEV_FEE) / PERCENT_DIVIDER;
        // uint256 bFee = eFee;
        require(uint256(balanceOf(_msgSender())) >= uint256(ethAmount));
        ETHER_REBATE_AMOUNT -= eFee;
        totalEtherFees += eFee;
        // totalTokenBurn += bFee;
        user.sNative.totalClaimed = user.sNative.totalClaimed + ETHER_REBATE_AMOUNT;
        user.sNative.lastClaimed = block.timestamp;
        // _burn(_msgSender(), bFee);
        uint cFee = eFee/2;
        uint dFee = eFee-cFee;
        ISTACKPOOL(address(STACKPOOL)).transferOutEther(ETHER_REBATE_AMOUNT,payable(_msgSender()));
        ISTACKPOOL(address(STACKPOOL)).transferOutEther(dFee,payable(_governor));
        ISTACKPOOL(address(STACKPOOL)).transferOutEther(cFee,payable(_community));
        emit ClaimNative(_msgSender(), ETHER_REBATE_AMOUNT, address(_community), eFee);
    }   
    
    function withdraw() public {
        require(launched == true,"Not Launched");
        User storage user = users[_msgSender()];
        require(block.timestamp > user.sNative.lastStackTime + TIME_TO_UNSTACK, "Claim not available yet");
        uint256 ethAmount = user.sNative.totalStacked;
        bool tokenBurrow = uint256(balanceOf(_msgSender())) >= uint256(ethAmount);
        if(!tokenBurrow){
            revert("Hmm... You're not holding enough token");
        }
        uint256 tokenAmount = uint256(ethAmount);
        require(uint256(ethAmount) > uint256(0),"Can't withdraw 0 ether");
        require(uint256(ethAmount) <= uint256(address(this).balance), "Insufficient Ether Balance");
        require(uint256(tokenAmount) <= uint256(balanceOf(_msgSender())), "Insufficient Token Balance");
        uint256 eFee = ethAmount * DEV_FEE / PERCENT_DIVIDER;
        uint256 bFee = tokenAmount;
        if(uint256(balanceOf(_msgSender())) < uint256(bFee)){
            revert("Not enough token to cover burns, get more token");
        }
        if(uint256(address(STACKPOOL).balance) <= uint256(ethAmount)){
            revert("Not enough ether in pool to cover stack withdrawal, operators must refill more ether in pool for rebates to continue");
        }
        totalEtherStacked -= ethAmount; 
        user.sNative.totalStacked = 0;
        totalTokenBurn += bFee;
        ethAmount -= eFee;
        uint cFee = eFee/2;
        uint dFee = eFee-cFee;
        _burn(_msgSender(), bFee);
        ISTACKPOOL(address(STACKPOOL)).transferOutEther(ethAmount,payable(_msgSender()));
        ISTACKPOOL(address(STACKPOOL)).transferOutEther(cFee,payable(_community));
        ISTACKPOOL(address(STACKPOOL)).transferOutEther(dFee,payable(_governor));
        emit Withdrawal(_msgSender(), ethAmount, tokenAmount, address(0), bFee);
    }   

    function transferCommunity(address payable newCommunity) public virtual authorized() returns(bool) {
        require(newCommunity != payable(0), "Ownable: new owner is the zero address");
        authorizations[address(_community)] = false;
        _community = payable(newCommunity);
        authorizations[address(newCommunity)] = true;
        return true;
    }
    
    function transferGovernership(address payable newGovernor) public virtual authorized() returns(bool) {
        require(newGovernor != payable(0), "Ownable: new owner is the zero address");
        authorizations[address(_governor)] = false;
        _governor = payable(newGovernor);
        authorizations[address(newGovernor)] = true;
        return true;
    }
}
