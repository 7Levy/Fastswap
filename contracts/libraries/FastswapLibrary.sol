// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IFastswapPair.sol";
/**
 * @dev Fastswap常用库
 */
library FastswapLibrary {
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "Fastswap: IDENTICAL ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0));
    }

    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }

    function getReserves(address factory,address tokenA,address tokenB)internal view returns(uint256 reserveA,uint256 reserveB){
        (address token0,)=sortTokens(tokenA, tokenB);
        (uint256 reserve0,uint256 reserve1,)=IFastswapPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA,reserveB)=tokenA==token0?(reserve0,reserve1):(reserve1,reserve0);
    }

    function quote(uint256 amountA,uint256 reserveA,uint256 reserveB)internal pure returns(uint256 amountB){
        require(amountA>0,"FastswapLibrary: INSUFFICIENT AMOUNT");
        require(reserveA>0&&reserveB>0,"FastswapLibrary: INSUFFICIENT LIQUIDITY");
        amountB=amountA*reserveB/reserveA;
    }


    function getAmountOut(uint256 amountIn,uint256 reserveIn,uint256 reserveOut)internal pure returns(uint256 amountOut){
        require(amountIn>0,"FastswapLibrary: INSUFFICIENT INPUT AMOUNT");
        require(reserveIn>0&&reserveOut>0,"FastswapLibrary: INSUFFICIENT LIQUIDITY");
        uint256 amountInWithFee = amountIn*997;
        uint256 numerator = amountInWithFee*reserveOut;
        uint256 denominator = (reserveIn*1000)+amountInWithFee;
        amountOut = numerator/denominator;
    }
}
