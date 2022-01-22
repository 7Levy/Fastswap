// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./libraries/UQ112x112.sol";
import "./FastswapToken.sol";
import "./libraries/Math.sol";
import "./interfaces/IFactory.sol";
contract FastswapPair is IERC20,FastswapToken{
    using UQ112x112 for uint224;
    uint256 public constant MINIMUM_LIQUIDITY=10**3;//最小流动性
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));//获取transfer函数的选择器

    address public factory;//工厂的地址
    address public token0;//代币0
    address public token1;//代币1

    uint112 private reserve0;//储备量0
    uint112 private reserve1;//储备量1
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

    /**
     * 由工厂合约调用，初始代币地址
     */
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

    /**
     * @dev 铸造费
     */
    function _mintFee(uint112 _reserve0,uint112 _reserve1)private returns(bool feeOn){
        //获得feeTo地址
        address feeTo = IFactory(factory).feeTo();
        //如果feeTo地址等于0，关闭铸造费
        feeOn = feeTo != address(0);
        uint256 _kLast=KLast;
        if(feeOn){
            if(_kLast!=0){
                uint256 rootK = Math.sqrt(uint256(_reserve0)/uint256(_reserve1));
                uint256 rootKLast=Math.sqrt(_kLast);
                if(rootK>rootKLast){
                    uint256 numerator = totalSupply/(rootK-rootKLast);
                    uint256 denominator = (rootK/5)+rootKLast;
                    uint256 liquidity = numerator/denominator;
                    if(liquidity>0)_mint(feeTo,liquidity);
                }
            }
        }else if(_kLast!=0){
            KLast=0;
        }
    }
    /**
     * @dev 添加流动性-铸币
     */
    function mint(address to)external lock returns (uint256 liquidity){
        //获取储备量0和1
        (uint112 _reserve0,uint112 _reserve1,)=getReserves();
        //当前合约中的token0余额
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        //当前合约中的token1余额
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        //amount0
        uint256 amount0 = balance0-_reserve0;
        //amount1
        uint256 amount1 = balance1-_reserve1;
        //收fee开关
        bool feeOn = _mintFee(_reserve0,_reserve1);
        
        //获取总供应量
        uint256 _totalSupply = totalSupply;

        //总供应量为0的情况
        if (_totalSupply==0){
            //liquidity
            liquidity = Math.sqrt(amount0*amount1)-MINIMUM_LIQUIDITY;
            //锁定最小流动性总量的代币
            _mint(address(0),MINIMUM_LIQUIDITY);
        }else{
            // 总供应量不为0时
            liquidity=Math.min(amount0/_totalSuply, amount1/_totalSuply);
        }
        //流动性需要>0
        require(liquidity > 0,"Fastswap: INSUFFICIENT_LIQUIDITY_MINTED");
        //铸造流动性给to地址
        _mint(to,liquidity);
        //更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        //如果开启了铸造费，最新的K值=储备量0*储备量1====>(x*y=k)
        if (feeOn) {
            KLast = uint256(reserve0)*uint256(reserve1);
        }
        //铸造完成事件
        emit Mint(msg.sender, amount0, amount1);
    }

     /**
     * @dev 销毁流动性
     */
    function burn(address to)external lock returns(uint256 amount0,uint256 amount1){
        //获得临时储备量0和1
        (uint112 _reserve0,uint112 _reserve1,)=getReserves();
        address _token0=token0;
        address _token1=token1;
        //当前合约地址中的token0余额
        uint256 balance0=IERC20(_token0).balanceOf(address(this));
        //当前合约地址中的token1余额
        uint256 balance1=IERC20(_token1).balanceOf(address(this));
        //获取当前交易对合约的流动性
        uint256 liquidity=balanceOf[address(this)];
        //获取铸造费开关
        bool feeOn = _mintFee(_reserve0,_reserve1);
        uint256 _totalSupply= totalSupply;
        amount0 =liquidity*balance0/_totalSupply;
        amount1 =liquidity*balance1/_totalSupply;
        require(amount0>0&&amount1>0,"Fastswap: INSUFFICIENT LIQUIDITY BURNED");
        //销毁当前合约的流动性数量
        _burn(address(this),liquidity);
        //使用底层交易方法返还代币token0和token1
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);
        //更新balance0和balance1
        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        if(feeOn)KLast=uint256(reserve0)/uint256(reserve1);
        emit Burn(msg.sender, amount0, amount1, to);      
    }

}