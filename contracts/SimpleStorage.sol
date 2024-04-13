// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract SimpleStorage {
  // 有一个名为 storedData 的状态变量，存储一个整数。
  // 有一个 set 函数，接收一个整数参数，并将其存储在 storedData 中。
  // 有一个 get 函数，返回 storedData 中存储的整数值。

  uint256 storedData;

  function set(uint256 value) public {
    require(value > 0, "must be > 0");
    storedData = value;
  }

  function get() public view returns (uint256) {
    return storedData;
  }
}
