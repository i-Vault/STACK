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

import "./utils/INTERFACES.sol";
import "./iOwn.sol";

contract STACK_POOL is iOwn, ISTACKPOOL {
    /**
     * address  
     */
    address payable public _governor;
    // 0x987576AEc36187887FC62A19cb3606eFfA8B4023
    address payable public _community = payable(0x050134fd4EA6547846EdE4C4Bf46A334B7e87cCD);
    
    /**
     * strings  
     */
    string constant _name = "KEK STACK POOL";
    string constant _symbol = "STACKPOOL";
    
    /**
     * bools  
     */
    bool internal initialized;

    /**
     * Function modifiers 
     */
    modifier onlyGovernor() virtual {
        require(isGovernor(_msgSender()), "!GOVERNOR"); _;
    }

    constructor () iOwn(_community,_msgSender()) payable {
        _governor = payable(_msgSender());
        initialize(_governor); 
    }

    fallback() external payable {
    }
    
    receive() external payable {
    }

    function name() external pure returns (string memory) { return _name; }
    function getOwner() external view returns (address) { return Governor(); }

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
    
    function transferOutToken(uint256 amount, address payable receiver, address token) public virtual override authorized() returns (bool) {
        assert(address(receiver) != address(0));
        uint sTb = IERC20(token).balanceOf(address(this));
        require(uint(sTb) >= uint(amount),"not enough balance in token");
        IERC20(token).transfer(payable(receiver), amount);
        return true;
    }
    
    function transferOutEther(uint _amount, address payable _address) public payable override authorized() returns (bool) {
        bool sent = false;
        uint sTb = address(this).balance;
        require(uint(sTb) >= uint(_amount),"not enough balance in ether");
        assert(address(_address) != address(0));
        (bool safe,) = payable(_address).call{value: _amount}("");
        require(safe == true);
        sent = safe;
        return sent;
    }

    function initialize(address payable governance) private {
        require(initialized == false);
        _governor = payable(governance);
        iOwn.authorize(address(governance));
        iOwn.authorize(address(_community));
        initialized = true;
    }
    
    function authorizeSTACK(address payable stack) public virtual authorized() {
        require(initialized == true);
        _governor = payable(stack);
        iOwn.authorize(address(stack));
    }
    
    function transferGovernership(address payable newGovernor) public virtual authorized() returns(bool) {
        require(newGovernor != payable(0), "Ownable: new owner is the zero address");
        authorizations[address(_governor)] = false;
        _governor = payable(newGovernor);
        authorizations[address(newGovernor)] = true;
        return true;
    }
}
