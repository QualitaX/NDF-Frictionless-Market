// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./Types.sol";

abstract contract NDFStorage {
    mapping(address => uint256) internal margin;
    mapping(uint256 => address) internal pendingRequests;
    mapping(address => Types.MarginRequirement) internal marginRequirements;

    error obseleteFunction();
    error InvalidPosition(int256 position);
    error InvalidPartyAddress(address party);
    error cannotInceptWithYourself(address _caller, address _withParty);
    error InvalidUpfrontPayment(uint256 paymentAmount, uint256 requiredAmount);
    error InvalidAddressOrTradeData(address _inceptor, uint256 _dataHash);

    event MarginEvaluated(
        address indexed payer,
        address indexed payee,
        uint256 netAmount,
        uint256 payerMargin,
        uint256 payeeMargin,
        uint256 timestamp
    );

    uint256 internal initialMargin;
    uint256 internal maintenanceMargin;
    uint256 internal terminationFee;
    uint256 internal inceptionTime;
    uint256 internal confirmationTime;

    Types.TradeState internal tradeState;
    Types.SettlementType internal settlementType; // Cash or Physical

    address internal frictionlessTreasury;
    address internal frictionlessFXSwapAddress;
    address internal marginEvaluationUpkeepAddress;
    address internal settlementUpkeepAddress;
    string internal tradeId;
    string internal tradeDataHash;

    // Chainlink Price Feed Variables
    AggregatorV3Interface internal exchangePriceFeed;
    uint256 internal currentExchangeRate;
    uint256 internal exchangePriceDecimals;
}