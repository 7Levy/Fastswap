// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IFactory.sol";
import "./FastswapPair.sol";

contract FastswapFactory is IFactory {
    address public feeTo; //收fee地址
    address public feeToSetter; //设置收fee地址的地址
    mapping(address => mapping(address => address)) public onepair; //交易对，A=>B=>pairAB
    address[] public allPairs; //存放所有交易对

    //交易对合约创建时生成的字节码
    bytes32 public constant PAIR_CREATIONCODE_HASH =
        keccak256(abi.encodePacked(type(FastswapPair).creationCode));

    //事件-创建配对成功
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    /**
     * @dev 初始化合约的时候设置feeToSetter地址
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @dev 获取交易对数组的长度
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @dev 创建交易对
     */
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair)
    {
        //交易对两个代币A和B的地址不能相同
        require(tokenA != tokenB, "Fastswap: IDENTICAL ADDRESSES");
        //按照地址大小排序token0和token1
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        //token的地址不为0
        require(token0 != address(0), "Fastswap: ZERO_ADDRESS");
        //判断是否已经存在该交易对
        require(
            onepair[token0][token1] == address(0),
            "Fastswap: PARI ALREADY EXISTS"
        );

        bytes memory bytecode = type(FastswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        //对token0和token1进行排序后，汇编生成可预测的交易对地址
        //solium-disable-next-line
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        //初始化FastswapPair合约的交易对token0和token1
        IERC20(pair).initialize(token0, token1);
        //设置交易对映射
        onepair[token0][token1] = pair;
        onepair[token1][token0] = pair;
        //存储交易对映射
        allPairs.push(pair);
        //创建交易对成功后的事件
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev 设置接收fee的地址
     */
    function setFeeto(address _feeTo) external {
        //判断是否有权限设置接收fee的地址
        require(msg.sender == feeToSetter, "Fastswap: INVALID");
        feeTo = _feeTo;
    }

    /**
     * @dev 获取feeTo地址
     */
    function feeTo() external view returns (address) {
        return feeTo;
    }
    
    /**
     * @dev 转移权限
     */
    function setFeeToSetter(address _feeToSetter) external {
        //判断是否可以转移所拥有权限
        require(msg.sender == feeToSetter, "Fastsawp: IVALID");
        feeToSetter = _feeToSetter;
    }
}
