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
        (uint256 amount0, uint256 amount1) = IFastswapPair(pair).burn(to);
        (address token0, ) = FastswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amountA, amountB)
            : (amountB, amountA);
        require(
            amountA >= amountAMin,
            "FastswapRouter01: INSUFFICIENT A AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "FastswapRouter01: INSUFFICIENT B AMOUNT"
        );
    }

    /**
     * @dev 移除ETH-ERC20流动性
     */

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        //销毁流动性
        (amountToken, amountETH) = removeLiquidiy(
            toekn,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /**
     * @dev 带签名的移除流动性
     */

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB) {
        //计算TokenA，TokenB的CREATE2地址
        address pair = FastswapLibrary.pairFor(factory, tokenA, tokenB);
        //如果批准全部，value等于uint256的最大值
        uint256 value = approveMax ? type(uint256).max : liquidity;
        //签名授权，调用者、当前合约地址、值、截止时间、v、r、s
        IFastswapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    /**
     * @dev 带签名的移除ETH流动性
     */

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH) {
        address pair = FastswapLibrary.pairFor(factory, token, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IFastswapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountETH) = removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    /**
     * @dev 交换的私有方法
     */
    function _swap(
        uin256[] memory amounts,
        address[] memory path,
        address _to
    ) private {
        for (uin256 i; i < path.length - 1; i++) {
            //输入地址，输出地址
            (address input, address output) = (path[i], path[i + 1]);
            //地址排序
            (address token0, ) = FastswapLibrary.sortTokens(input, output);
            //输出数额
            uin256 amountOut = amounts[i + 1];

            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uin256(0), amountOut)
                : (amountOut, uint256(0));

            //计算to地址
            address to = i < path.length - 2
                ? FastswapLibrary.pairFor(factory, output, path[i + 2])
                : _to;

            //交换代币
            IFastswapPair(FastswapLibrary.pairFor(factory, input, output)).swap(
                    amount0Out,
                    amount1Out,
                    to,
                    new bytes(0)
                );
        }
    }

    /**
     * @dev ERC20-ERC20精确兑换(精确换多)
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = FastswapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "FastswapRouter01: INSUFFICIENT OUTPUT AMOUNTS"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FastswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    /**
     * @dev ERC20-ERC20精确兑换(少换精确)
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = FastswapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "FastswapRouter01: EXCESSIVE INPUT AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FastswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    /**
     * @dev ExactETH-ERC20
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        //确保第一个代币为WETH
        require(path[0] == WETH, "FastswapRouter01: INVALID PATH");
        amounts = FastswapLibrary.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "FastswapRouter01,INSUFFICIENT OUTPUT AMOUNT"
        );
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IWETH(WETH).transfer(
                FastswapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
    }

    /**
     * @dev ERC20-ExactETH
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(
            path[path.length - 1] == WETH,
            "FastswapRouter01: INVALID PATH"
        );
        amounts = FastswapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "FastswapRouter01: EXCESSIVE INPUT AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            FastswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        reuqire(
            path[path.length - 1] == WETH,
            "FastswapRouter01: INVALID PATH"
        );
        amounts = FastswapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "FastswapRouter01: INSUFFICIENT OUTPUT AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender.FastswapLibrary.pairFor(factory, path[0], path[1])
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        reuqire(path[0] == WETH, "FastswapRouter01: INVALID PATH");
        amounts = FastswapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= msg.value,
            "FastswapRouter01: EXCESSIVE INPUT AMOUNT"
        );
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IWETH(WETH).transfer(
                FastswapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
        if (msg.value > amounts[0]) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
        }
    }
        function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure returns (uint256 amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        return UniswapV2Library.getAmountOut(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
