// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Types.sol";

abstract contract NDFStorage {
    mapping(address => uint256) internal margin;
    mapping(uint256 => address) internal pendingRequests;

    Types.TradeState internal tradeState;

    uint256 internal initialMargin;
    uint256 internal maintenanceMargin;
    uint256 internal terminationFee;
    address internal treasury;
    string internal tradeId;
}