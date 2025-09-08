// SPDX-License-Identifier: MIT
/**
 * Copyright © 2024  Frictionless Group Holdings S.à.r.l
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of the Frictionless protocol smart contracts
 * (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next paragraph) shall be included in all copies
 * or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL FRICTIONLESS GROUP
 * HOLDINGS S.à.r.l OR AN OF ITS SUBSIDIARIES BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */
pragma solidity ^0.8.19; 

import { IBasicFrictionlessToken } from "./IBasicFrictionlessToken.sol";

/**
 * @title FrictionlessOnChainAssetToken is the extension of the ERC-3643 Token to represent OnChain Assets
 * @author Frictionless Group Holdings S.à.r.l
 * @notice Implementation of the storage of the underlying OnChain Asset and it's data.
 */
interface IFrictionlessOnChainAssetToken is IBasicFrictionlessToken {
    /// @dev Enum for the schedule of the payments by the Manager, either pro_rat or coupon/bullet style.
    enum FrictionlessOnChainAssetSchedule {
        // The Manager will make payments for the `FrictionlessOnChainAssetToken` on an coupon_only basis, with a bullet payment for the principal investment.
        SCHEDULE_COUPON_ONLY,
        // The Manager will make pro-rata payments for the `FrictionlessOnChainAssetToken` for both the principal investment and the coupon.
        SCHEDULE_PRO_RATA
    }

    /// @dev Enum for the periodicity of payments by the Manager
    enum FrictionlessOnChainAssetPaymentFrequency {
        // Payments from the Manager for the `FrictionlessOnChainAssetToken` are made daily
        PAYMENT_FREQUENCY_DAILY,
        // Payments from the Manager for the `FrictionlessOnChainAssetToken` are made weekly
        PAYMENT_FREQUENCY_WEEKLY,
        // Payments from the Manager for the `FrictionlessOnChainAssetToken` are made monthly
        PAYMENT_FREQUENCY_MONTHLY,
        // Payments from the Manager for the `FrictionlessOnChainAssetToken` are made quarterly
        PAYMENT_FREQUENCY_QUARTERLY,
        // Payments from the Manager for the `FrictionlessOnChainAssetToken` are made semi-annually
        PAYMENT_FREQUENCY_SEMI_ANNUALLY,
        // Payments from the Manager for the `FrictionlessOnChainAssetToken` are made annually
        PAYMENT_FREQUENCY_ANNUALLY,
        // Payments from the Manager for the `FrictionlessOnChainAssetToken` are made once
        PAYMENT_FREQUENCY_SINGLE
    }

    /// @dev Enum for the yield for this `FrictionlessOnChainAssetToken` is a fixed/floating rate
    enum FrictionlessOnChainAssetYieldType {
        // The yield for this `FrictionlessOnChainAssetToken` is a fixed rate
        YIELD_FIXED,
        // The yield for this `FrictionlessOnChainAssetToken` is a floating rate
        YIELD_FLOATING
    }

    /// @dev Enum for the price quote status obtained at auction
    enum FrictionlessOnChainAssetPriceStatus {
        // The `FrictionlessOnChainAssetToken` did not receive enough offers at the offer price
        PRICE_QUOTE_STATUS_UNDER_SUBSCRIBED,
        // The aggregate bid at auction matched the offer
        PRICE_QUOTE_STATUS_PRICED_AT_PAR,
        // The aggregate bid at auction is lower than the offer
        PRICE_QUOTE_STATUS_PRICED_AT_DISCOUNT,
        // The aggregate bid at auction is higher than the offer
        PRICE_QUOTE_STATUS_PRICED_AT_PREMIUM
    }

    /// @dev Enum for the current status of the `FrictionlessOnChainAssetToken`. Updated over time by the Treasury
    enum FrictionlessOnChainAssetStatus {
        // Status reserved for `FrictionlessOnChainAssetToken` that are MINTED onChain
        STATUS_MINTED,
        // Status reserved for `FrictionlessOnChainAssetToken` that are fully purchased, which means they have minted the digital securities.
        STATUS_PURCHASED,
        // Status reserved for `FrictionlessOnChainAssetToken` that have reached their maturity event
        STATUS_MATURED,
        // Status reserved for `FrictionlessOnChainAssetToken` that are in an impaired state. The parValue may be affected.
        STATUS_IMPAIRED,
        // Status reserved for `FrictionlessOnChainAssetToken` that are fully matured and have been fully redeemed.
        STATUS_REDEEMED
    }

    /// @dev Enum for the current S&P style riskGrade of the `FrictionlessOnChainAssetToken`. Updated over time by the Manager/Treasury/Risk Oracle.
    enum FrictionlessOnChainAssetRiskGrade {
        BER_AAA,
        BER_AA,
        BER_A,
        BER_BBB,
        BER_BB,
        BER_B,
        BER_CCC,
        BER_CC,
        BER_C,
        BER_D,
        BER_UNRATED
    }

    /**
     * @dev The specification data for the `FrictionlessOnChainAssetToken`, this is an immutable data struct.
     * @param issuedOn the date this `FrictionlessOnChainAssetToken` is issued by the legal Issuer, Frictionless Markets S.à.r.l
     * @param maturityDays the number of days to maturity for this `FrictionlessOnChainAssetToken`
     * @param schedule the schedule of the payments by the Manager, either pro_rat or coupon/bullet style.
     * @param paymentFrequency the periodicity of payments by the Manager
     * @param yieldType the yield for this `FrictionlessOnChainAssetToken` is a fixed/floating rate
     * @param baseCurrency the currrency the `FrictionlessOnChainAssetToken` is issued in.
     * @param stripTotal the principal amount for the `FrictionlessOnChainAssetToken`
     * @param name the name for the `FrictionlessOnChainAssetToken`
     * @param symbol the ticker symbol for the `FrictionlessOnChainAssetToken`
     */
    struct FOCASpecData {
        uint256 issuedOn;
        uint256 maturityDays;
        FrictionlessOnChainAssetSchedule schedule;
        FrictionlessOnChainAssetPaymentFrequency paymentFrequency;
        FrictionlessOnChainAssetYieldType yieldType;
        string baseCurrency;
        uint256 stripTotal;
        string name;
        string symbol;
    }

    /**
     * @dev The issuance data for the `FrictionlessOnChainAssetToken`, this is an immutable data struct.
     * @param auctionedOn the date this `FrictionlessOnChainAssetToken` is auctioned by the legal Issuer, Frictionless Markets S.à.r.l
     * @param priceQuoteStatus the price quote status obtained at auction
     * @param onChainAssetUUID the off-chain UUID in the graphQL for the token
     * @param issuerUUID the off-chain UUID in the graphQL for the Manager issuing via the legal Issuer, Frictionless Markets S.à.r.l
     * @param isin the ISIN numbre or equivalent for the `FrictionlessOnChainAssetToken`
     * @param issuanceDocs the location of the issuance docs accessible via URI or the hash of the issuance docs.
     * @param assetClass the Managers/Issuers definition of the underlying asset class for the `FrictionlessOnChainAssetToken`
     */
    struct FOCAIssuanceData {
        uint256 auctionedOn;
        FrictionlessOnChainAssetPriceStatus priceQuoteStatus;
        string onChainAssetUUID;
        string issuerUUID;
        string isin;
        string issuanceDocs;
        string assetClass;
    }

    /**
     * @dev The uopdatable data for the `FrictionlessOnChainAssetToken`.
     * @param maturesOn the date this `FrictionlessOnChainAssetToken` fully matures. Updatable if the underlying fund is extended.
     * @param total the total value of the `FrictionlessOnChainAssetToken` (strip + yield over time). Updatable based on Manager IRRs, totalReturn, etc.
     * @param status the current status of the `FrictionlessOnChainAssetToken`. Updated over time by the Treasury
     * @param yield the current yield being paid on the `FrictionlessOnChainAssetToken`. Updated over time by the Manager/Calculating Agent.
     * @param riskGrade the current riskGrade of the `FrictionlessOnChainAssetToken`. Updated over time by the Manager/Treasury/Risk Oracle.
     * @param pullToParValue the calculation of the pullToPar value of this `FrictionlessOnChainAssetToken`. Updated over time by the Manager/Calculating Agent
     * @param custodianAddress the address of the custodian for the `FrictionlessOnChainAssetToken`
     */
    struct FOCAUpdateData {
        uint256 maturesOn;
        uint256 total;
        FrictionlessOnChainAssetStatus status;
        uint256 yield;
        FrictionlessOnChainAssetRiskGrade riskGrade;
        uint256 pullToParValue;
        address custodianAddress;
    }

    /// @dev error throw if there is an attempt to modify the immutable data.
    error FrictionlessOnChainAssetTokenUnableToUpdateData();

    /**
     * @dev Sets the specData data for the `FrictionlessOnChainAssetToken`.
     * throws `FrictionlessOnChainAssetTokenUnableToUpdateData` This data is immutable, an attempt to modify will generate the error `FrictionlessOnChainAssetTokenUnableToUpdateData`
     * @param specData the specData data for the `FrictionlessOnChainAssetToken`
     */
    function setSpecificationData(FOCASpecData calldata specData) external;

    /**
     * @dev Sets the issuanceData data for the `FrictionlessOnChainAssetToken`
     * throws `FrictionlessOnChainAssetTokenUnableToUpdateData` This data is immutable, an attempt to modify will generate the error `FrictionlessOnChainAssetTokenUnableToUpdateData`
     * @param issuanceData the updatable data for the `FrictionlessOnChainAssetToken`
     */
    function setIssuanceData(FOCAIssuanceData calldata issuanceData) external;

    /**
     * @dev Sets the updatable data for the `FrictionlessOnChainAssetToken`
     * @param updateData the updatable data for the `FrictionlessOnChainAssetToken`
     */
    function setUpdateData(FOCAUpdateData calldata updateData) external;

    /**
     * @dev Get the specData data for the `FrictionlessOnChainAssetToken`.
     * @return the specData data for the `FrictionlessOnChainAssetToken`
     */
    function getSpecificationData() external view returns (FOCASpecData memory);

    /**
     * @dev Get the issuanceData data for the `FrictionlessOnChainAssetToken`.
     * @return the issuanceData data for the `FrictionlessOnChainAssetToken`
     */
    function getIssuanceData() external view returns (FOCAIssuanceData memory);

    /**
     * @dev Get the updateData data for the `FrictionlessOnChainAssetToken`.
     * @return the updateData data for the `FrictionlessOnChainAssetToken`
     */
    function getUpdateData() external view returns (FOCAUpdateData memory);

    /**
     * @dev Get the currency the `FrictionlessOnChainAssetToken` is issued in.
     * @return the currency the `FrictionlessOnChainAssetToken` is issued in.
     */
    function getCurrency() external view returns (string memory);
}