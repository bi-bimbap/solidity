// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
Constant product AMM XY = K

https://solidity-by-example.org/defi/constant-product-amm/
https://www.youtube.com/watch?v=JSZbvmyi_LE&list=PLO5VPQH6OWdVQwpQfw9rZ67O6Pjfo6q-p&index=67
*/

import "./ERC20.sol";

contract CPAMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint public reserve0; // bal of token0
    uint public reserve1; // bal of token1

    uint public totalSupply; // total shares
    mapping(address => uint) public balanceOf; // total shares per user

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    // mint shares
    function _mint(address _to, uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    // burn shares
    function _burn(address _from, uint _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    // update reserve state vars
    function _update(uint _res0, uint _res1) private {
        reserve0 = _res0;
        reserve1 = _res1;
    }

    // copied from uniswap codebase
    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // returns the min of 2 uints
    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    // swap token0 for token1 vice versa
    function swap(address _tokenIn, uint _amountIn) external returns (uint amountOut) {
        require(_tokenIn == address(token0) || _tokenIn == address(token1), "invalid token");
        require(_amountIn > 0, "amount in = 0");

        // transfer token in 
        bool isToken0 = _tokenIn == address(token0);
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = isToken0 ?
            (token0, token1, reserve0, reserve1) : 
            (token1, token0, reserve1, reserve0);
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        
        // calc amt out (including fees), tx fee 0.3%
        // calc amount in (after deducting 0.3% fee)
        uint amountInWithFee = (_amountIn * 997) / 1000;
        /*
        How much dy for dx?

        xy = k
        (x + dx)(y - dy) = k
        y - dy = k / (x + dx)
        y - k / (x + dx) = dy
        y - xy / (x + dx) = dy
        (yx + ydx - xy) / (x + dx) = dy
        ydx / (x + dx) = dy
        */
        amountOut = (reserveOut * amountInWithFee) / (amountInWithFee +  reserveIn);

        // transfer token out
        tokenOut.transfer(msg.sender, amountOut);

        // update reserves
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    // users add 2 pairs of tokens
    // add tokens to contract, mint shares to user
    function addLiquidity(uint _amount0, uint _amount1) external returns (uint shares) {
        // transfer token in
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        // mint shares
        /*
        How much dx, dy to add?

        xy = k
        (x + dx)(y + dy) = k'

        No price change, before and after adding liquidity
        x / y = (x + dx) / (y + dy)

        x(y + dy) = y(x + dx)
        x * dy = y * dx

        x / y = dx / dy
        dy = y / x * dx
        */
        if (reserve0 > 0 || reserve1 > 0) {
            require(reserve0 * _amount1 == reserve1 * _amount0, "dy / dx != y / x");
        }

        // f(x, y) = value of liquidity = sqrt(xy)
        // s = dx / x * T = dy / y * T
        if (totalSupply == 0) {
            shares = _sqrt(_amount0 * _amount1);
        }
        else {
            shares = _min(
                (_amount0 * totalSupply) / reserve0,
                (_amount1 * totalSupply) / reserve1
            );
        }

        require(shares > 0, "shares > 0");

        _mint(msg.sender, shares);

        // update reserves
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    // withdraw tokens from contract, burn shares
    function removeLiquidity(uint _shares) external returns (uint amount0, uint amount1) {
        // calc amount0 & amount1 to withdraw
        /*
        Claim
        dx, dy = amount of liquidity to remove
        dx = s / T * x
        dy = s / T * y
        */
        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));

        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "amount0 or amount1 = 0");

        // burn shares
        _burn(msg.sender, _shares);

        // update reserves
        _update(bal0 - amount0, bal1 - amount1);

        // transfer tokens to msg.sender
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }
}
