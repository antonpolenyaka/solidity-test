// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "IRouter.sol";
import "IFactory.sol";
import "IPair.sol";

contract Test is Ownable {
    address[] public routers;
    address[] public connectors;
    // Key - router, value - factory
    mapping(address => address) _factories;

    constructor() {
        // Default configuration for testing in TestNet
        routers.push(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // PancakeRouter
        routers.push(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); // SushiSwapRouter = UniswapV2Router02
        _factories[
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        ] = 0x6725F303b657a9451d8BA641348b6761A6CC7a17;
        _factories[
            0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
        ] = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
        connectors.push(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); // BEP20Token
        connectors.push(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd); // USDT
        connectors.push(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd); // WBNB
        // MainNet
        // routers.push(0x10ED43C718714eb63d5aA57B78B54704E256024E); // PancakeRouter
        // routers.push(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); // SushiSwapRouter = UniswapV2Router02
        // routers.push(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8); // BiswapRouter02
        // routers.push(0x325E343f1dE602396E256B67eFd1F61C3A6B38Bd); // BabyRouter
    }

    /**
     * Set routers and auto reset factories
     * @param routers_ Array of router addresses (Pancake, Sushi, Biswap, Bakery, Baby, ... in BSC).
     */
    function setRouters(address[] calldata routers_) external onlyOwner {
        routers = routers_;
        for (uint256 i = 0; i < routers_.length; i++) {
            _factories[routers_[i]] = IRouter(routers[i]).factory();
        }
    }

    /**
     * Set connectors
     * @param connectors_ Array of connector addresses
     */
    function setConnectors(address[] calldata connectors_) external onlyOwner {
        connectors = connectors_;
    }

    /**
     * Gets router* and path* that give max output amount with input amount and tokens
     * @param amountIn Input amount
     * @param tokenIn Source token
     * @param tokenOut Destination token
     * @return amountOut Max output amount and router and path, that give this output amount
     * @return router Uniswap-like Router
     * @return path Token list to swap
     */
    function quote(
        uint amountIn,
        address tokenIn,
        address tokenOut
    )
        external
        view
        returns (uint amountOut, address router, address[] memory path)
    {
        require(amountIn > 0, "Test: input amount must to be greater 0!");
        require(tokenIn != address(0), "Test: source token is zero address!");
        require(tokenOut != address(0), "Test: source token is zero address!");
        require(
            tokenIn != tokenOut,
            "Test: source token must be different to destination!"
        );
        require(routers.length > 0, "Test: is not defined any router!");

        amountOut = 0;
        router = address(0);
        path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        for (uint256 i = 0; i < routers.length; i++) {
            address factory = _factories[routers[i]];
            address pair = IFactory(factory).getPair(tokenIn, tokenOut);
            // Check if pair exist in this swap
            if (pair != address(0)) {
                (uint112 reserve0, uint112 reserve1, ) = IPair(pair)
                    .getReserves();
                // Check INSUFFICIENT_LIQUIDITY
                if (reserve0 > 0 && reserve1 > 0) {
                    uint256 amountOutTemp = IRouter(routers[i]).quote(
                        amountIn,
                        reserve0,
                        reserve1
                    );
                    if (amountOutTemp > amountOut) {
                        amountOut = amountOutTemp;
                        router = routers[i];
                    }
                }
            }
        }
    }

    /**
     * Swaps tokens on router with path, should check slippage
     * @param amountIn Input amount
     * @param amountOutMin Minumum output amount
     * @param router Uniswap-like router to swap tokens on
     * @param path Tokens list to swap
     * @return amountOut Actual output amount
     */
    function swap(
        uint amountIn,
        uint amountOutMin,
        address router,
        address[] memory path
    ) external returns (uint amountOut, uint256[] memory amounts) {
        require(
            amountIn > 0 && amountOutMin > 0,
            "Test: amounts must to be greater 0!"
        );
        require(_isAllowedRouter(router), "Test: router is not allowed!");
        require(
            path.length == 2 || path.length == 3,
            "Test: allowed path [source, connector*, destination]!"
        );
        address tokenIn = path[0];
        require(tokenIn != address(0), "Test: source token is zero address!");
        address tokenOut;
        if (path.length == 3) {
            address connector = path[1];
            require(
                _isAllowedConnector(connector),
                "Test: connector is not allowed!"
            );
            tokenOut = path[2];
        } else {
            tokenOut = path[1];
        }
        require(
            tokenOut != address(0),
            "Test: destination token is zero address!"
        );

        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "Test: Token to contract transferFrom failed."
        );
        require(
            IERC20(tokenIn).approve(router, amountIn),
            "Test: Contract approve router failed."
        );
        amounts = IRouter(router).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            block.timestamp
        );

        amountOut = amounts[1];
    }

    /**
     * Check if this router is allowed to use
     * @param router_ Router to check
     * @return isAllowed Allowed=True
     */
    function _isAllowedRouter(
        address router_
    ) private view returns (bool isAllowed) {
        isAllowed = false;
        for (uint256 i = 0; i < routers.length; i++) {
            if (routers[i] == router_) {
                isAllowed = true;
                break;
            }
        }
    }

    /**
     * Check if this connector is allowed to use
     * @param connector_ Connector to check
     * @return isAllowed Allowed=True
     */
    function _isAllowedConnector(
        address connector_
    ) private view returns (bool isAllowed) {
        isAllowed = false;
        for (uint256 i = 0; i < routers.length; i++) {
            if (connectors[i] == connector_) {
                isAllowed = true;
                break;
            }
        }
    }
}
