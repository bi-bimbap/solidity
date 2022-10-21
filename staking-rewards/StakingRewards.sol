// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
This is a minimal example of a contract that rewards users for staking their token.

https://solidity-by-example.org/defi/staking-rewards/
https://www.youtube.com/watch?v=iNZWMj4USUM&t=27s
https://www.youtube.com/watch?v=OJ-IRzCYSXI&list=PLO5VPQH6OWdVQwpQfw9rZ67O6Pjfo6q-p&index=69
*/

import "./ERC20.sol";

contract StakingRewards {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;

    uint public duration;  // Duration of rewards to be paid out (in seconds)
    uint public finishAt;  // Timestamp of when the rewards finish
    uint public updatedAt; // Minimum of last updated time and reward finish time
    uint public rewardRate; // Reward to be paid out per second
    uint public rewardPerTokenStored; // Sum of (reward rate * dt * 1e18 / total supply)
    mapping(address => uint) public userRewardPerTokenPaid; // User address => rewardPerTokenStored
    mapping(address => uint) public rewards; // User address => rewards to be claimed

    uint public totalSupply; // total staked
    mapping(address => uint) public balanceOf; // // User address => staked amount

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _stakingToken, address _rewardsToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    function _min(uint _x, uint _y) private pure returns (uint) {
        return _x <= _y ? _x : _y;
    }

    // owner - set rewards duration
    function setRewardsDuration(uint _duration) external onlyOwner {
        // ensure owner does not change the duration once it is set
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    // owner - set reward rate
    function notifyRewardAmount(uint _amount) external onlyOwner updateReward(address(0)) {
        // case 1: reward duration expired/not started
        if (block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        }
        // case 2: reward duration not finished, staking still ongoing
        else { 
            uint remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingRewards + _amount) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        // check enough rewards to be paid out
        require(rewardsToken.balanceOf(address(this)) >= rewardRate * duration, "reward amount > balance");

        finishAt  = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    // user - stake tokens
    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        // transfer tokens in 
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        // update amt staked by user
        balanceOf[msg.sender] += _amount;
        // update total staked tokens in contract
        totalSupply += _amount;
    }

    // user - withdraw tokens staked
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        // update amt staked by user
        balanceOf[msg.sender] -= _amount;
        // update total staked tokens in contract
        totalSupply -= _amount;
        // transfer tokens out
        stakingToken.transfer(msg.sender, _amount);
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        else {
            return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18 ) / totalSupply;
        }
    }
    
    // calc rewards earned for staking
    function earned(address _account) public view returns (uint) {
        // rewards = (tokens staked * (reward per token - rewards already paid)) + rewards
        return ((balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18 ) + rewards[_account];
    }

    // user - claim rewards
    function getRewards() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];

        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }
}
