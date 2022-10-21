// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
Constant sum AMM X + Y = K
Tokens trade one to one.

https://solidity-by-example.org/defi/constant-sum-amm/
https://www.youtube.com/watch?v=Luff_OGvYtI&list=PLO5VPQH6OWdVQwpQfw9rZ67O6Pjfo6q-p&index=74
*/

import "./ERC20.sol";

contract CSAMM {
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

    // trade token for another token
    function swap(address _tokenIn, uint _amountIn) external returns (uint amountOut) {
        require(_tokenIn == address(token0) || _tokenIn == address(token1), "invalid token");

        bool isToken0 = _tokenIn == address(token0);
        (IERC20 tokenIn, IERC20 tokenOut, uint resIn, uint resOut) = isToken0 ? 
            (token0, token1, reserve0, reserve1) : 
            (token1, token0, reserve1, reserve0);

        // transfer token in
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        uint amountIn = tokenIn.balanceOf(address(this)) - resIn;

        // before refactoring code
        // uint amountIn;
        // if (_tokenIn == address(token0)) {
        //     token0.transferFrom(msg.sender, address(this), _amountIn);
        //     amountIn = token0.balanceOf(address(this)) - reserve0;
        // }
        // else {
        //     token1.transferFrom(msg.sender, address(this), _amountIn);
        //     amountIn = token1.balanceOf(address(this)) - reserve1;
        // }

        // calc amount out (including fees)
        // dx (amt of token in) = dy (amt of token out)
        // assuming 0.3% trading fee
        amountOut = (amountIn * 997) / 1000;

        // update reserve0 & reserve1
        (uint res0, uint res1) = isToken0 ? 
            (resIn + _amountIn, resOut - amountOut) :
            (resOut - amountOut, resIn + _amountIn);
        
        _update(res0, res1);

        // before refactoring code
        // if (_tokenIn == address(token0)) {
        //     _update(reserve0 + _amountIn, reserve1 - amountOut);
        // }
        // else {
        //     _update(reserve0 - amountOut, reserve1 + _amountIn);            
        // }

        // transfer token out
        tokenOut.transfer(msg.sender, amountOut);

        // before refactoring code
        // if (_tokenIn == address(token0)) {
        //     token1.transfer(msg.sender, amountOut);
        // }
        // else {
        //     token0.transfer(msg.sender, amountOut);
        // }
    }

    // add tokens to contract, mint shares to user
    function addLiquidity(uint _amount0, uint _amount1) external returns (uint shares) {
        // transfer token in
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        // balance in reserve0 & reserve1
        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));

        // amount in
        uint d0 = bal0 - reserve0;
        uint d1 = bal1 - reserve1;
        
        // calc shares to mint
        /*
        a = amount in
        L = total liquidity
        s = shares to mint
        T = total supply

        s should be proportional to increase from L to L + a
        (L + a) / L = (T + s) / T

        s = a * T / L
        */
        if (totalSupply == 0) {
            shares = d0 + d1;
        }
        else {
            shares = ((d0 + d1) * totalSupply) / (reserve0 + reserve1);
        }

        // mint shares to user
        require(shares > 0, "shares == 0");
        _mint(msg.sender, shares);

        // update reserve0 & reserve1
        _update(bal0, bal1);
    }
    
    // remove tokens from contract, burn shares
    function removeLiquidity(uint _shares) external returns (uint d0, uint d1) {
        /*
        a = amount out
        L = total liquidity
        s = shares
        T = total supply

        a / L = s / T

        a = L * s / T
          = (reserve0 + reserve1) * s / T
        */
        // calc amt to return to user
        d0 = (reserve0 * _shares) / totalSupply;
        d1 = (reserve1 * _shares) / totalSupply;

        // burn shares from user
        _burn(msg.sender, _shares);

        // update reserve0 & reserve1
        _update(reserve0 - d0, reserve1 - d1);

        if (d0 > 0) {
            token0.transfer(msg.sender, d0);
        }
        else {
            token1.transfer(msg.sender, d1);
        }
    }
}
