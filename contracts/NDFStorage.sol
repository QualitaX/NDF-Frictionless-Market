// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Types.sol";

abstract contract NDFStorage {
    mapping(address => uint256) internal margin;
    mapping(uint256 => address) internal pendingRequests;
    mapping(address => Types.MarginRequirement) internal marginRequirements;

    Types.TradeState internal tradeState;

    error obseleteFunction();
    error InvalidPosition(int256 position);
    error InvalidPartyAddress(address party);
    error cannotInceptWithYourself(address _caller, address _withParty);
    error InvalidUpfrontPayment(uint256 paymentAmount, uint256 requiredAmount);
    error InvalidAddressOrTradeData(address _inceptor, uint256 _dataHash);

    uint256 internal initialMargin;
    uint256 internal maintenanceMargin;
    uint256 internal terminationFee;
    uint256 internal inceptionTime;
    uint256 internal confirmationTime;
    Types.SettlementType internal settlementType; // Cash or Physical

    address internal frictionlessTreasury;
    address frictionlessFXSwapAddress;
    address internal marginEvaluationUpkeepAddress;
    address internal settlementUpkeepAddress;
    string internal tradeId;
    string internal tradeDataHash;
}