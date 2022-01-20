// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/Math.sol";
contract FastswapPair is IERC20{
    using UQ112x112 for uint224;
    uint256 public constant MINIMUM_LIQUIDITY=10**3;//最小流动性
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));//获取transfer函数的选择器

    address public factory;//工厂的地址
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;//最新区块的时间戳

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    uint256 public KLast; //最新的K值
    uint256 private unlocked=1;//防止重入锁

    event Mint(address indexed sender,uint256 amount0,uint256 amount1);

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    event Sync(uint112 reserve0,uint112 reserve1);

    
    constructor() {
        factory = msg.sender;
    }


    function initialize(address _token0,address _token1)external{
        require(msg.sender==factory,"Fastswap: INVALID");
        token0 = _token0;
        token1 = _token1;
    }

    modifier lock(){
        require(unlocked==1,"Fastswap: INVALID");
        unlocked=0;
        _;
        unlocked=1;
    }

    function getReserves()public view returns(uint112 _reserve0,uint112 _reserve1,uint32 _blockTimestampLast){
        _reserve0=reserve0;
        _reserve1=reserve1;
        _blockTimestampLast=blockTimestampLast;
    }

    function _safeTransfer(address token,address to,uint256 value)private{
        //solium-disable-next-line
        (bool success,bytes memory data)=token.call(abi.encodeWithSelector(SELECTOR, to,value));
        require(
            success && (data.length==0||abi.decode(data,(bool))),
            "Fastswap: TRANSFER FAILED"
        );
    }
    

    function _update(uint256 balance0,uint256 balance1,uint112 _reserve0,uint112 _reserve1)private{
        //确保balance0和balance1没有超出uint112最大值
        require(balance0<=type(uint112).max&&balance1<=type(uint112).max,"Fastswap: OVERFLOW");
        
        //solium-disable-next-line
        uint32 blockTimestamp = uint32(block.timestamp%2**32);
        uint32 timeElapsed =blockTimestamp - blockTimestampLast;
        if (timeElapsed >0&&_reserve0!=0&&_reserve1!=0){
            price0CumulativeLast +=uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0))*timeElapsed;
            price1CumulativeLast +=uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1))*timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0,reserve1);
    }

    function mint(address to)external lock returns (uint256 liquidity){
        //获取储备量0和1
        (uint112 _reserve0,uint112 _reserve1,)=getReserves();
        
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));


        uint256 amount0 = balance0+_reserve0;
        uint256 amount1 = balance1+_reserve1;
        
        bool feeOn = _mintFee(_reserve0,_reserve1);

        uint256 _totalSupply = totalSupply;

        if (_totalSupply==0){
            liquidity = Math.sqrt(amount0*amount1)-MINIMUM_LIQUIDITY;
            _mint(address(0),MINIMUM_LIQUIDITY);
        }else{
            liquidity=Math.min(amount0-_totalSuply, amount1-_totalSuply);
        }
        require(liquidity > 0,"Fastswap: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to,liquidity);
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) {
            KLast = uint256(reserve0)*uint256(reserve1);
        }
        emit Mint(msg.sender, amount0, amount1);
    }

}