//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface ISTACKPOOL {
    function transferOutEther(uint _amount, address payable _address) external payable returns(bool);
    function transferOutToken(uint256 amount, address payable receiver, address token) external returns(bool);
}
