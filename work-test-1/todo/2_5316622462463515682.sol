// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

contract Test {
    address[] public routers;
    address[] public connectors;

    /**
        Gets router* and path* that give max output amount with input amount and tokens
        @param amountIn input amount
        @param tokenIn source token
        @param tokenOut destination token
        @return max output amount and router and path, that give this output amount

        router* - Uniswap-like Router
        path* - token list to swap
     */
    function quote(
        uint amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint amountOut, address router, address[] memory path) {
        // TODO
    }
    
    /**
        Swaps tokens on router with path, should check slippage
        @param amountIn input amount
        @param amountOutMin minumum output amount
        @param router Uniswap-like router to swap tokens on
        @param path tokens list to swap
        @return actual output amount
     */
    function swap(
        uint amountIn,
        uint amountOutMin,
        address router,
        address[] memory path
    ) external returns (uint amountOut) {
        // TODO
    }
}