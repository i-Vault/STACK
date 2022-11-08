//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Auth.sol";

abstract contract iOwn is _MSG {
    address private owner;
    mapping (address => bool) internal authorizations;

    constructor(address _community,address _governor) {
        initialize(address(_community),address(_governor));
    }

    modifier onlyOwner() virtual {
        require(isOwner(_msgSender()), "!OWNER"); _;
    }

    modifier onlyZero() virtual {
        require(isOwner(address(0)), "!ZERO"); _;
    }

    modifier authorized() virtual {
        require(isAuthorized(_msgSender()), "!AUTHORIZED"); _;
    }
    
    function initialize(address _community,address _governor) private {
        owner = _community;
        authorizations[_community] = true;
        authorizations[_governor] = true;
    }

    function authorize(address adr) internal virtual authorized() {
        authorizations[adr] = true;
    }

    function unauthorize(address adr) internal virtual authorized() {
        authorizations[adr] = false;
    }

    function isOwner(address account) public view returns (bool) {
        if(account == owner){
            return true;
        } else {
            return false;
        }
    }

    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }
    
    function transferAuthorization(address fromAddr, address toAddr) public virtual authorized() returns(bool) {
        require(fromAddr == _msgSender());
        bool transferred = false;
        authorize(address(toAddr));
        unauthorize(address(fromAddr));
        owner = toAddr;
        transferred = true;
        return transferred;
    }
}
