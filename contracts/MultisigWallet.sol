// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";

// 设计一个多重签名钱包合约。这个钱包要求一组所有者中的一定数量同意后才能执行交易。包括添加和移除所有者、提交、批准和执行交易的功能。
contract MultisigWallet is Context {
  // -------------------- copy openzeppelin and change ------------------------------
  event RoleGranted(address indexed account, address indexed sender);
  event RoleRevoked(address indexed account, address indexed sender);

  error AccessControlBadConfirmation();
    error AccessControlUnauthorizedAccount(address account);

  struct IndexValue {
    uint keyIndex;
    bool hasRole;
  }

  struct keyFlag {
    address key;
    bool deleted;
  }

  mapping(address account => IndexValue) roleData;
  keyFlag[] keys;

  modifier onlyOwner() {
    if (!hasRole(_msgSender()))
      revert AccessControlUnauthorizedAccount(_msgSender());
    
    _;
  }

  function hasRole(address account) internal view returns (bool) {
    return roleData[account].hasRole;
  }

  function _grantRole(address account) internal returns (bool) {
    if (!hasRole(account)) {
        if(roleData[account].keyIndex > 0){
          keys[roleData[account].keyIndex - 1].deleted = false;
        } else {
          keys.push();
          keys[keys.length - 1].key = account;
          roleData[account].keyIndex = keys.length;
        }

        roleData[account].hasRole = true;

        emit RoleGranted(account, _msgSender());
        return true;
    } else {
        return false;
    }
  }

  function _revokeRole(address account) internal returns (bool) {
    if (hasRole(account)) {
        roleData[account].hasRole = false;
        keys[roleData[account].keyIndex - 1].deleted = true;
        emit RoleRevoked(account, _msgSender());
        return true;
    } else {
        return false;
    }
  }

  function iteratorSkipDelete(
    uint keyIndex
  ) private view returns (uint) {
    while (keyIndex < keys.length && (keys[keyIndex].deleted))
      keyIndex++;

    return keyIndex;
  }
  // ---------------------------------------------------------------------------------

  bytes32 constant WalletOwner = keccak256("WALLET_OWNER");
  uint24 constant limitTimeFrame = 12 hours;
  uint ownerNum;
  uint256 balances;

  enum EventType {
    GrantOwner,
    RevokeOwner,
    Transfer
  }

  enum EventState {
    Success,
    Expired,
    Progress
  }

  struct EventMessage {
    EventType eventType;
    uint amount;
    address from;
    address to;
    uint ownerNum;
    uint agreedVote;
    mapping (address => bool) agreedOwners;
    uint expiredTime;
    EventState eventState;
  }

  mapping(bytes key => EventMessage) eventMessage;

  event NotifyForApproval(bool, bytes);
  event Received(address, uint);

  constructor() {
    _grantRole(_msgSender());
  }

  modifier createEventMessage(EventType eventType, address to, uint amount) {
    bytes memory key = abi.encodePacked(_msgSender(), to, block.timestamp);
    eventMessage[key].eventType = eventType;
    eventMessage[key].amount = amount;
    eventMessage[key].from = _msgSender();
    eventMessage[key].to = to;
    eventMessage[key].ownerNum = ownerNum;
    eventMessage[key].expiredTime = block.timestamp + limitTimeFrame;
    eventMessage[key].eventState = EventState.Progress;

    notifyForApproval(key);
    _;
  }

  function grantOwner(address owner) public onlyOwner createEventMessage(EventType.GrantOwner, owner, 0) {}
  function revokeOwner(address owner) public onlyOwner createEventMessage(EventType.RevokeOwner, owner, 0) {}
  function MakeTransfer(address to, uint value) public onlyOwner createEventMessage(EventType.Transfer, to, value) {}

  function grantRole(address owner) internal {
    _grantRole(owner);
    ownerNum++;
  }

  function revokeRole(address owner) internal {
    if (ownerNum == 1)
      revert("At least one Owner");

    _revokeRole(owner);
    ownerNum--;
  }

  /// 发起转装
  function _MakeTransfer(address to, uint value) internal {
    require(balances > value, "Balances not enough");
    balances -= value;
    payable(to).transfer(value);
  }

  /*
   * push the message when transferring to other owner
   */
  function notifyForApproval(bytes memory eventMessageKey) internal {
    for (uint i = 0; i < keys.length; i = iteratorSkipDelete(i+1)) {
      if (keys[i].key != eventMessage[eventMessageKey].from) {
        bytes memory message = abi.encodePacked(
          eventMessage[eventMessageKey].eventType, 
          eventMessage[eventMessageKey].amount, 
          eventMessage[eventMessageKey].from, 
          eventMessage[eventMessageKey].to, 
          eventMessage[eventMessageKey].ownerNum, 
          eventMessage[eventMessageKey].expiredTime
        );
        (bool isSuccess, bytes memory _data) = payable(keys[i].key).staticcall(message);
        emit NotifyForApproval(isSuccess, _data);
      }
    }
  }

  // error notify
  // function notifyResend(EventMessage storage data) internal {
  //   bytes memory message = abi.encodePacked(
  //     data.eventType, 
  //     data.amount, 
  //     data.from, 
  //     data.to, 
  //     data.ownerNum, 
  //     data.expiredTime
  //   );

  //   (bool isSuccess, bytes memory _data) = payable(data.to).staticcall(message);
  //   emit NotifyForApproval(isSuccess, _data);
  // }

  /*
   * decide upon receipt of notification
   * the method can't be used after a certain period of the time
   */
  function decide(bytes calldata key) public onlyOwner {
    require(!eventMessage[key].agreedOwners[_msgSender()], "You already voted");

    // 规定时间内处理完成，否则取消
    if (eventMessage[key].expiredTime < block.timestamp) {
      eventMessage[key].eventState = EventState.Expired;
    }

    if(eventMessage[key].eventState == EventState.Expired) {
      revert("The event has been expried");
    } else if(eventMessage[key].eventState == EventState.Success) {
      revert("The event has been success");
    } 

    eventMessage[key].agreedOwners[_msgSender()] = true;
    // Operation must be more than half
    if (eventMessage[key].agreedVote++ > eventMessage[key].ownerNum / 2) {
      if (eventMessage[key].eventType == EventType.GrantOwner) {
        grantRole(eventMessage[key].to);
      } else if (eventMessage[key].eventType == EventType.RevokeOwner) {
        revokeRole(eventMessage[key].to);
      } else if (eventMessage[key].eventType == EventType.Transfer) {
        _MakeTransfer(eventMessage[key].to, eventMessage[key].amount);
      }

      eventMessage[key].eventState = EventState.Success;
    }
  }

  // 接受转账
  receive() external payable {
    balances += msg.value;
    emit Received(_msgSender(), msg.value);
  }
}

