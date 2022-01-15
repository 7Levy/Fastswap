// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IFactory.sol";
import "./FastswapPair.sol";

contract FastswapFactory is IFactory {
    address public feeTo; //收fee地址
    address public feeToSetter; //设置收fee地址的地址
    mapping(address => mapping(address => address)) public pair;//交易对，A=>B=>pairAB
    address[] public allPairs; //存放所有交易对

    //交易对合约创建时生成的字节码
    bytes32 public constant PAIR_CREATIONCODE_HASH= keccak256(abi.encodePacked(type(FastswapPair).creationCode));
    
    //事件-创建配对成功
    event PairCreated(address indexed token0,address indexed token1,address pair,uint);

    /**
     * @dev 初始化合约的时候设置feeToSetter地址
     */
    constructor(address _feeToSetter)public{
        feeToSetter=_feeToSetter;
    }

    /**
     * @dev 获取交易对数组的长度 
     */
    function allPairsLength()external view returns(uint){
        return allPairs.length;
    }



}
