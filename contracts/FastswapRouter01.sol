// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IFastswapRouter01.sol";
import "./interfaces/IFactory.sol";
import "./libraries/FastswapLibrary.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IFastswapPair.sol";
import "./interfaces/IWETH.sol";

contract FastswapRouter01 is IFastswapRouter01 {
    //部署的工厂地址和weth地址
    address public factory;
    address public WETH;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "FastswapRouter01: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }

    /**
     * @dev 添加流动性底层方法
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) private returns (uint256 amountA, uint256 amountB) {
        //获取交易对，如果不存在，则创建
        if (IFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = FastswapLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = FastswapLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "FastswapRouter01: INSUFFICIENT B AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = FastswapLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "FastswapRouter01: INSUFFICIENT A AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /**
     * @dev 添加ERC20对流动性池子
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        //获取amountA,获取amountB
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        //获取TokenA和TokenB的交易对合约
        address pair = FastswapLibrary.pairFor(factory, tokenA, tokenB);
        //发送TokenA到交易对合约
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        //发送TokenB到交易合约
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        //铸造流动性
        liquidity = IFastswapPair(pair).mint(to);
    }

    /**
     * @dev 添加ETH流动性
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        //获取Token和ETH的数量
        (amountToken, amountETH) = _addLiquidity(
            tokenA,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        //获取token和WETH的交易对合约地址
        address pair = FastswapLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        //向WETH合约存储amountETH数量的WETH代币，.value用于调用合约的时候设置msg.value
        IWETH(WETH).deposit{value: amountETH}();
        //发送WETH到交易对合约
        assert(IWETH(WETH).transfer(pair, amountETH));
        //铸造流动性
        liquidity = IFastswapPair(pair).mint(to);
        //如果收到的ETH数量大于amountETH，返还给调用者多余的代币
        if (msg.value > amountETH) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        }
    }

    /**
     * @dev 移除ERC20对流动性
     */

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = FastswapLibrary.pairFor(factory, tokenA, tokenB);
        //返还流动性代币Fast
        IFastswapPair(pair).transferFrom(msg.sender, pair, liquidity);
        //销毁Fast代币，计算TokenA和TokenB的数量
        (uint256 amount0,uint256 amount1)=IFastswapPair(pair).burn(to);
        (address token0,)=FastswapLibrary.sortTokens(tokenA, tokenB);
        (amountA,amountB)=tokenA==token0?(amountA,amountB):(amountB,amountA);
        require(amountA>=amountAMin,"FastswapRouter01: INSUFFICIENT A AMOUNT");
        require(amountB>=amountBMin,"FastswapRouter01: INSUFFICIENT B AMOUNT");
    }


    
}
