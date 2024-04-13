// SPDX-License-Identifier: UNLICENSED

// 实现一个投票合约，允许用户为预先定义的选项投票。合约应该包含添加候选项、投票和查看当前获胜候选项的功能。
pragma solidity ^0.8.24;

struct IndexValue {
  uint40 keyIndex;
  uint40 vote;
}

struct keyFlag {
  address key;
  bool deleted;
}

struct itmap {
  mapping(address => IndexValue) data;
  keyFlag[] keys;
  uint40 size;
}

type Iterator is uint40;

library IterableMapping {
  function add(
    itmap storage self,
    address key
  ) internal returns (bool repleace) {
    uint40 keyIndex = self.data[key].keyIndex;
    if (keyIndex > 0) {
      require(self.keys[keyIndex - 1].deleted, "Key Exist");

      self.keys[keyIndex - 1].deleted = false;

      return true;
    } else {
      keyIndex = uint40(self.keys.length);
      self.keys.push();
      self.keys[keyIndex].key = key;
      self.data[key].keyIndex = keyIndex + 1;
      self.size++;

      return false;
    }
  }

  function remove(
    itmap storage self,
    address key
  ) internal returns (bool success) {
    uint40 keyIndex = self.data[key].keyIndex;
    if (keyIndex == 0) revert("Not Exist");

    require(!self.keys[keyIndex - 1].deleted, "Already Remove");

    self.keys[keyIndex - 1].deleted = true;
    delete self.data[key];
    self.size--;

    return true;
  }

  function iterateStart(itmap storage self) internal view returns (Iterator) {
    return iteratorSkipDelete(self, 0);
  }

  function iterateValid(
    itmap storage self,
    Iterator iterator
  ) internal view returns (bool) {
    return Iterator.unwrap(iterator) < self.keys.length;
  }

  function iterateNext(
    itmap storage self,
    Iterator iterator
  ) internal view returns (Iterator) {
    return iteratorSkipDelete(self, Iterator.unwrap(iterator) + 1);
  }

  function iterateGet(
    itmap storage self,
    Iterator iterator
  ) internal view returns (address addressIndex, uint40 value) {
    addressIndex = self.keys[Iterator.unwrap(iterator)].key;
    value = self.data[addressIndex].vote;
  }

  function iteratorSkipDelete(
    itmap storage self,
    uint40 keyIndex
  ) private view returns (Iterator) {
    while (keyIndex < self.keys.length && self.keys[keyIndex].deleted)
      keyIndex++;

    return Iterator.wrap(keyIndex);
  }
}

contract Voting {
  using IterableMapping for itmap;
  itmap candidates;

  struct votingInfo {
    address cast;
    bool voted;
  }
  mapping(address => votingInfo) voter;

  uint immutable startTime;
  uint immutable endTime;
  address owner;

  struct Winner {
    address _winner;
    uint40 _voteTally;
  }
  Winner[] winners;

  modifier OnlyOwner {
    require(msg.sender == owner, "Must be Owner");
    _;
  }

  event AddCandidate(address candidate);
  event RemoveCandidate(address candidate);

  constructor(uint40 _startTime, uint40 _endTime) {
    require(
      _startTime < _endTime,
      "The start time should be less than the end time"
    );
    startTime = _startTime;
    endTime = _endTime;
    owner = msg.sender;
  }

  function addCandidateBeforeTheStart(address candidate) public OnlyOwner {
    require(
      block.timestamp < startTime,
      "Candidate should be added before the start time"
    );
    candidates.add(candidate);
    emit AddCandidate(candidate);
  }

  function removeCandidateBeforeTheStart(address candidate) public OnlyOwner {
    require(
      block.timestamp < startTime,
      "Candidate should be remove before the start time"
    );

    candidates.remove(candidate);
    emit RemoveCandidate(candidate);
  }

  function castTheVote(address candidate) public {
    require(voter[msg.sender].voted == false, "You have already voted");
    require(block.timestamp >= startTime, "Voting has not begun");
    require(block.timestamp < endTime, "Out of time for voting");

    voter[msg.sender].cast = candidate;
    voter[msg.sender].voted = true;

    candidates.data[candidate].vote += 1;
  }

  function winner() public  returns (Winner[] memory) {
    require(block.timestamp >= endTime, "Voting has not yet closed");

    for (
      Iterator i = candidates.iterateStart();
      candidates.iterateValid(i);
      i = candidates.iterateNext(i)
    ) {
      (address addressIndex, uint40 value) = candidates.iterateGet(i);
      if (winners[0]._voteTally <= value && value != 0) {
        if (winners[0]._voteTally < value) 
          delete winners;

        winners.push();
        winners[winners.length - 1]._voteTally = value;
        winners[winners.length - 1]._winner = addressIndex;
      }
    }

    return winners;
  }
}
