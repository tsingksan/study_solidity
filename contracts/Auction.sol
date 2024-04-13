// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// - 创建一个拍卖合约，允许用户出价。合约应当记录当前最高出价和最高出价者，并允许新的出价只在超过当前最高出价时被接受。考虑拍卖结束时如何处理资金和如何声明获胜者。

contract Auction {
  uint startTime;
  uint endTime;

  address payable public beneficiary;

  struct Highest {
    uint price;
    address bidder;
  }

  Highest highest;

  mapping(address => uint) pendingReturns;

  event HighestBidIncreased(address bidder, uint amount);
  event AuctionEnded(address winner, uint amount);

  modifier effectiveTime {
    require(block.timestamp >= startTime);
    require(block.timestamp < endTime);
    _;
  }

  constructor(address payable beneficiaryAddress) {
    beneficiary = beneficiaryAddress;
  }

  function bid(uint _pirce) external effectiveTime payable {
    require(_pirce > highest.price);

    if (highest.price != 0) {
      pendingReturns[msg.sender] += msg.value;
    }
    highest.price = _pirce;
    highest.bidder = msg.sender;
    emit HighestBidIncreased(msg.sender, msg.value);
  }

  function withdraw() external returns (bool) {
    uint amount = pendingReturns[msg.sender];
    if (amount > 0) {
      pendingReturns[msg.sender] = 0;

      if (!payable(msg.sender).send(amount)) {
          // No need to call throw here, just reset the amount owing
          pendingReturns[msg.sender] = amount;
          return false;
      }
    }

    return true;
  }

  function endAuction() external effectiveTime {
    emit AuctionEnded(highest.bidder, highest.price);
    beneficiary.transfer(highest.price);
  }
}
