// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

interface IProxy {
    function initialize()external;
    function getPeopleAge()external pure returns(uint256);
}

contract LogicTest{
    address public proxy;

    constructor(address _proxy) {
        proxy = _proxy;
    }
    function test() public view returns(uint256) {
        console.log("in test function:");
        return IProxy(proxy).getPeopleAge();
    }
}

