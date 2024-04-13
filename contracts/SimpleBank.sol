// 编写一个 Solidity 合约，实现一个简单的存款与取款功能的银行合约。用户可以向银行存款，并从银行取款，但不能取出超过自己的存款金额。确保实现存款和取款功能的安全性，防止溢出和下溢。
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract SimpleBank {
  mapping(address => uint256) private balances;

  event Withdraw(uint256 money);

  function deposit() public payable {
    require(msg.value > 0, "Please deposit some money");

    balances[msg.sender] += msg.value;
  }

  function withdraw(uint256 amount) public {
    require(amount > 0, "Withdrawal amount must be greater than zero");
    require(balances[msg.sender] >= amount, "Not enough money");
    balances[msg.sender] -= amount;

    payable(msg.sender).transfer(amount);
    emit Withdraw(amount);
  }

  function getBalance() public view returns (uint256) {
    return balances[msg.sender];
  }
}
