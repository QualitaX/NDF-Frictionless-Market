// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

abstract contract Types {
    struct IRS {
        address partyA;
        address partyB;
        address partyACollateralCurrency;
        address partyBCollateralCurrency;
        address settlementCurrency;
        int256 spread;
        uint256 notionalAmount;
        uint256 startDate;
        uint256 maturityDate;
    }

    struct MarginRequirement {
        uint256 marginBuffer;
        uint256 terminationFee;
    }
    
    struct IRSReceipt {
        address from;
        address to;
        uint256 netAmount;
        uint256 timestamp;
        uint256 conversionRate;
        uint256 partyAPaymentAmount;
        uint256 partyBPaymentAmount;
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
}