// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

//import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./Types.sol";

abstract contract NDFStorage {
    mapping(address => Types.Margin) internal margin;
    mapping(uint256 => address) internal pendingRequests;
    mapping(address => Types.MarginRequirement) internal marginRequirements;

    error obseleteFunction();
    error NoMarginNeeded();
    error invalidTrade(string _tradeID);
    error InvalidAddress(address addr);
    error InvalidPosition(int256 position);
    error InvalidPartyAddress(address party);
    error cannotInceptWithYourself(address _caller, address _withParty);
    error InvalidUpfrontPayment(uint256 paymentAmount, uint256 requiredAmount);
    error InvalidAddressOrTradeData(address _inceptor, uint256 _dataHash);
    error stateMustBeConfirmedOrSettled();

    modifier onlyWhenTradeInactive() {
        require(
            tradeState == Types.TradeState.Inactive,
            "Trade state is not 'Inactive'."
        ); 
        _;
    }

    modifier onlyWhenTradeIncepted() {
        require(
            tradeState == Types.TradeState.Incepted,
            "Trade state is not 'Incepted'."
        );
        _;
    }

    modifier onlyWhenTradeConfirmed() {
        require(
            tradeState == Types.TradeState.Confirmed,
            "Trade state is not 'Confirmed'." 
        );
        _;
    }

    modifier onlyWhenSettled() {
        require(
            tradeState == Types.TradeState.Settled,
            "Trade state is not 'Settled'."
        );
        _;
    }

    modifier onlyWhenValuation() {
        require(
            tradeState == Types.TradeState.Valuation,
            "Trade state is not 'Valuation'."
        );
        _;
    }

    modifier onlyWhenInTermination () {
        require(
            tradeState == Types.TradeState.InTermination,
            "Trade state is not 'InTermination'."
        );
        _;
    }

    modifier onlyWhenInTransfer() {
        require(
            tradeState == Types.TradeState.InTransfer,
            "Trade state is not 'InTransfer'."
        );
        _;
    }

    modifier onlyWhenMatured() {
        require(
            tradeState == Types.TradeState.Matured,
            "Trade state is not 'Matured'."
        );
        _;
    }

    modifier onlyWhenConfirmedOrSettled() {
        if(tradeState != Types.TradeState.Confirmed) {
            if(tradeState != Types.TradeState.Settled) {
                revert stateMustBeConfirmedOrSettled();
            }
        }
        _;
    }

    modifier onlyWithinConfirmationTime() {
        require(
            block.timestamp - inceptionTime <= confirmationTime,
            "Confimartion time is over"
        );
        _;
    }

    event MarginCall(
        address indexed payer,
        address indexed payee,
        int256 netAmount,
        int256 payerMargin,
        int256 payeeMargin,
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
    uint256 internal terminationFee;
    uint256 internal inceptionTime;
    uint256 internal confirmationTime;
    int256 internal variationMargin;
    int256 internal previousMarkToMarket;

    Types.TradeState internal tradeState;
    Types.SettlementType internal settlementType; // Cash or Physical
    Types.Receipt[] internal receipts;

    address internal frictionlessFXSwapAddress;
    address internal marginEvaluationUpkeepAddress;
    address internal settlementUpkeepAddress;
    string internal tradeId;
    string internal tradeDataHash;
    address internal payerParty;

    // Chainlink Price Feed Variables
    //AggregatorV3Interface internal exchangePriceFeed;
    int256 internal currentExchangeRate;
    uint256 internal exchangePriceDecimals;
    uint256 internal netSettlementAmount; // in settlement currency
    uint256 internal marginCallAmount; // in settlement currency

    address public ratesContractAddress;
}