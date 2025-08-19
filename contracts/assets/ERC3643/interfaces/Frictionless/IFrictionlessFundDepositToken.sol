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
 * @title FrictionlessFundDepositToken - A Fund Deposit Token represents a permissioned Investors FIAT contribution to a specific fund IBAN in a denominated FIAT currency.
 * @author Frictionless Group Holdings S.à.r.l
 * @notice A Fund Deposit Token represents a permissioned Investors FIAT contribution to a specific fund IBAN in a denominated FIAT currency.
 * The Fund Deposit Token is used as a means of payment and settlement. The Fund Deposit Token can only be transferred between permissioned Investors in the fund.
 * A daily attestation of the fund IBAN serves to prove the 1:1 backing with FIAT.
 * Exclusively under Frictionless Markets S.à.r.l issuance terms Investors holding a `FrictionlessFundDepositToken` have the legal right to the FIAT value held in the fund IBAN account.
 */
interface IFrictionlessFundDepositToken is IBasicFrictionlessToken {
    /**
     * @dev Struct which represents the immutable data in the Token. Once set it cannot be modified.
     * @param currency the FIAT denomination of the deposit token.
     * @param description the description of the deposit token
     * @param fundIBAN the IBAN which Frictionless Markets S.à.r.l holds a matching FIAT currency ledger with a G-SIB for this currency, attestations are provided on this IBAN.
     */
    struct FFDImmutableData {
        string currency;
        string description;
        string fundIBAN;
    }

    /// @dev error throw if there is an attempt to modify the immutable data.
    error FrictionlessFundDepositTokenUnableToUpdateInitData();

    /**
     * @dev Sets the immutable data for the `FrictionlessFundDepositToken`
     * @param initData the immutable data for the `FrictionlessFundDepositToken`
     */
    function setInitData(FFDImmutableData calldata initData) external;

    /**
     * @dev Get the currency the FIAT denomination of the deposit token.
     * @return the currency the FIAT denomination of the deposit token.
     */
    function getCurrency() external view returns (string memory);

    /**
     * @dev Get the description the description of the deposit token.
     * @return the description the description of the deposit token
     */
    function getDescription() external view returns (string memory);

    /**
     * @dev Get the IBAN which Frictionless Markets S.à.r.l holds a matching FIAT currency ledger with a G-SIB for this currency, attestations are provided on this IBAN.
     * This is restricted to onlyAgent roles.
     * @return the IBAN which Frictionless Markets S.à.r.l holds a matching FIAT currency ledger with a G-SIB for this currency, attestations are provided on this IBAN.
     */
    function getFundIBAN() external returns (string memory);
}