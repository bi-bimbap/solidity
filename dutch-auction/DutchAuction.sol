// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
Dutch auction for NFT.
- Seller of NFT deploys this contract setting a starting price for the NFT.
- Auction lasts for 7 days.
- Price of NFT decreases over time.
- Participants can buy by depositing ETH greater than the current price computed by 
  the smart contract.
- Auction ends when a buyer buys the NFT.

https://solidity-by-example.org/app/dutch-auction/
https://www.youtube.com/watch?v=Ykt2Wqt6pBQ&list=PLO5VPQH6OWdVQwpQfw9rZ67O6Pjfo6q-p&index=55
*/

interface IERC721 {
    function transferFrom(address _from, address _to, uint _nftId) external;
}

contract DutchAuction {
    uint private constant DURATION = 7 days; // "days" are compiled to seconds

    IERC721 public immutable nft;
    uint public immutable nftId;

    address payable public immutable seller;
    uint public immutable startingPrice;
    uint public immutable startAt;
    uint public immutable expiresAt;
    uint public immutable discountRate;

    constructor(uint _startingPrice, uint _discountRate, address _nft, uint _nftId) {
        seller = payable(msg.sender);
        startingPrice = _startingPrice;
        discountRate = _discountRate;
        startAt = block.timestamp;
        expiresAt = block.timestamp + DURATION;

        // check if starting price > 0
        require(_startingPrice >= _discountRate * DURATION, "starting price < discount");
        
        nft = IERC721(_nft);
        nftId = _nftId;
    }

    // calc NFT price when buyer calls buy()
    function getPrice() public view returns (uint) {
        uint timeElapsed = block.timestamp - startAt;
        uint discount = discountRate * timeElapsed;
        return startingPrice - discount;
    }

    function buy() external payable {
        // check that auction has not expired
        require(block.timestamp < expiresAt, "auction expired");

        // check that ETH sent is sufficient to buy NFT
        uint price = getPrice();
        require(msg.value >= price, "ETH < price");

        // transfer ownership of NFT
        nft.transferFrom(seller, msg.sender, nftId);

        // refund excess ETH to buyer
        // if buyer sends > price to pay
        uint refund = msg.value - price;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        // send ETH to seller & close auction
        selfdestruct(seller);
    }
}
