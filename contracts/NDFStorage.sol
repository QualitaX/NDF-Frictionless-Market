// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./Types.sol";

abstract contract NDFStorage {
    mapping(address => Types.Margin) internal margin;
    mapping(uint256 => address) internal pendingRequests;
    mapping(address => Types.MarginRequirement) internal marginRequirements;

    error obseleteFunction();
    error NoMarginNeeded();
    error InvalidAddress(address addr);
    error InvalidPosition(int256 position);
    error InvalidPartyAddress(address party);
    error cannotInceptWithYourself(address _caller, address _withParty);
    error InvalidUpfrontPayment(uint256 paymentAmount, uint256 requiredAmount);
    error InvalidAddressOrTradeData(address _inceptor, uint256 _dataHash);

    event MarginCall(
        address indexed payer,
        address indexed payee,
        uint256 netAmount,
        uint256 payerMargin,
        uint256 payeeMargin,
        uint256 timestamp
    );
    event MarginTopUp(address indexed party, uint256 topUpAmount, uint256 timestamp);
    event TradeSettled(
        uint256 settlementAmountInBaseCurrency,
        uint256 settlementAmountInSpotCurrency,
        int256 exchangeRateAtSettlement,
        int256 contractRate,
        uint256 timestamp
    );

    uint256 internal initialMargin;
    uint256 internal maintenanceMargin;
    uint256 internal terminationFee;
    uint256 internal inceptionTime;
    uint256 internal confirmationTime;
    int256 internal variationMargin;
    int256 internal previousMarkToMarket;

    Types.TradeState internal tradeState;
    Types.SettlementType internal settlementType; // Cash or Physical
    Types.Receipt[] internal receipts;

    address internal frictionlessTreasury;
    address internal frictionlessFXSwapAddress;
    address internal marginEvaluationUpkeepAddress;
    address internal settlementUpkeepAddress;
    string internal tradeId;
    string internal tradeDataHash;
    address internal payerParty;

    // Chainlink Price Feed Variables
    AggregatorV3Interface internal exchangePriceFeed;
    int256 internal currentExchangeRate;
    uint256 internal exchangePriceDecimals;
    uint256 internal netSettlementAmount; // in settlement currency
    uint256 internal marginCallAmount; // in settlement currency

    address public ratesContractAddress;
}