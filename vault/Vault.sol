// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
Simple example of vault contract, commonly used in DeFi protocols.
Most vaults on the mainnet are more complex. Here we will focus on the math for calculating shares to mint on deposit and the amount of token to withdraw.

How the contract works
- Some amount of shares are minted when an user deposits.
- The DeFi protocol would use the users' deposits to generate yield (somehow).
- User burn shares to withdraw his tokens + yield.

https://solidity-by-example.org/defi/vault/
https://www.youtube.com/watch?v=HHoa0c3AOqo&list=PLO5VPQH6OWdVQwpQfw9rZ67O6Pjfo6q-p&index=65
*/

import "./ERC20.sol";

contract Vault {
    IERC20 public immutable token;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function _mint(address _to, uint _amount) private {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
    }

    function _burn(address _from, uint _amount) private {
        totalSupply -= _amount;
        balanceOf[_from] -= _amount;
    }

    function deposit(uint _amount) external {
        /*
        formula to calculate shares to mint
        a = amount
        B = balance of token before deposit
        T = total supply
        s = shares to mint

        (T + s) / T = (a + B) / B 

        s = aT / B
        */

        uint shares;

        if (totalSupply == 0) {
            shares = _amount;
        }
        else {
            shares = (_amount * totalSupply) / token.balanceOf(address(this));
        }

        _mint(msg.sender, shares);
        token.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint _shares) external {
        /*
        formula to calculate amount to send back to user
        a = amount
        B = balance of token before withdraw
        T = total supply
        s = shares to burn

        (T - s) / T = (B - a) / B 

        a = sB / T
        */

        uint amount = (_shares * token.balanceOf(address(this))) / totalSupply;
        _burn(msg.sender, _shares);
        token.transfer(msg.sender, amount);
    }
}
