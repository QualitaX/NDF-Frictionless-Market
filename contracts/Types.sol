// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

abstract contract Types {
    struct IRS {
        address longParty;
        address shortParty;
        address collateralCurrency;
        address settlementCurrency;
        address baseCurrency;
        address spotCurrency;
        int256 contractRate;
        uint256 notionalAmount;
        uint256 startDate;
        uint256 maturityDate;
    }

    struct MarginRequirement {
        uint256 marginBuffer;
        uint256 terminationFee;
    }
    
    struct Receipt {
        address from;
        address to;
        uint256 netAmount;
        uint256 timestamp;
        uint256 conversionRate;
        uint256 partyAPaymentAmount;
        uint256 partyBPaymentAmount;
    }

    struct Margin {
        uint256 currentMargin;
        uint256 totalMarginPosted;
    }

    enum TradeState {
        Inactive,
        Incepted,
        Confirmed,
        Valuation,
        InTransfer,
        Settled,
        InTermination,
        Terminated,
        Matured
    }

    enum SettlementType {
        Cash,
        Physical
    }
}