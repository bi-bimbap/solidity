// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
English auction for NFT.

Auction
- Seller of NFT deploys this contract.
- Auction lasts for 7 days.
- Participants can bid by depositing ETH greater than the current highest bidder.
- All bidders can withdraw their bid if it is not the current highest bid.

After the auction
- Highest bidder becomes the new owner of NFT.
- The seller receives the highest bid of ETH.

https://solidity-by-example.org/app/english-auction/
https://www.youtube.com/watch?v=ZeFjGJpzI7E&list=PLO5VPQH6OWdVQwpQfw9rZ67O6Pjfo6q-p&index=56
*/

interface IERC721 {
    function safeTransferFrom(address from, address to, uint tokenId) external;
    function transferFrom(address, address, uint) external;
}

contract EnglishAuction {
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address highestBidder, uint amount);

    // NFT related state var
    IERC721 public immutable nft;
    uint public immutable nftId;

    // auction related state var
    address payable public immutable seller;
    uint32 public endAt;
    bool public started;
    bool public ended;

    // bidder related state var
    address public highestBidder;
    uint public highestBid;
    mapping(address => uint) public bids; // stores all bids that are not highest (to allow withdrawal)


    constructor(address _nft, uint _nftId, uint _startingBid) {
        nft = IERC721(_nft);
        nftId = _nftId;
        highestBid = _startingBid;
        seller = payable(msg.sender);
    }

    // seller to start the bid
    function start() external {
        // only seller can start the bid
        require(seller == msg.sender, "not seller");
        // only start if bid was not already started
        require(!started, "started");

        started = true;
        // block.timestamp is uint256, hence need to cast
        // can replace "60" with "7 days" for it to go on for 7 days
        endAt = uint32(block.timestamp + 60);

        // transfer ownership from seller to this contract
        nft.transferFrom(seller, address(this), nftId);

        emit Start();
    }

    // for bidders to bid
    function bid() external payable {
        require(started, "not started");
        require(block.timestamp < endAt, "ended");
        require(msg.value >= highestBid, "value < highest bid");

        // keep track bids that were outbid, so bidders can withdraw
        // ignore for the first run
        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        // update highest bid info
        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }

    // allow outbid bidders to withdraw ETH
    function withdraw() external payable {
        // to prevent reentrancy, reset bal = 0 before transfer ETH
        uint bal = bids[msg.sender];
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(bal);

        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "not started");
        require(!ended, "ended");
        require(block.timestamp >= endAt, "not ended");

        ended = true;

        // if nobody bid for the NFT, don't transfer ownership & send ETH 
        if (highestBidder != address(0)) {
            // transfer ETH to seller
            seller.transfer(highestBid);
            // transfer ownership of NFT
            nft.transferFrom(address(this), highestBidder, nftId);
        }
        else { // nobody participated in bid, transfer NFT back to seller
            nft.transferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }
}
