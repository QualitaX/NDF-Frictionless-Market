// SPDX-License-Identifier: MIT
/**
 * Copyright © 2024 Frictionless Group Holdings S.à.r.l
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
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL FRICTIONLESS
 * GROUP HOLDINGS S.à.r.l OR ANY OF ITS SUBSIDIARIES BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 * AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 */
pragma solidity ^0.8.19; 

import { IBasicFrictionlessToken } from "./IBasicFrictionlessToken.sol";

/**
 * @title IFrictionlessDigitalSecurityToken - The permissioned & transferable digital security which represents the future cash flow from the `FrictionlessOnChainAssetToken`.
 * @author Frictionless Group Holdings S.à.r.l
 * @notice This is the permissioned & transferable digital security which represents the future cash flow from the `FrictionlessOnChainAssetToken` and is purchased by
 * the Investor using `FrictionlessFundDepositTokens`. These digital securities are permissioned and transferable between permissioned Investors in a permissioned secondary market.
 * This token is linked to the `FrictionlessOnChainAssetToken` and denominated in a FIAT currency at a future date for settlement.
 */
interface IFrictionlessDigitalSecurityToken is IBasicFrictionlessToken {
    // @dev Enumeration to represent the type of the digital security, either a coupon (yield) or strip (principal)
    enum FrictionlessDigitalSecurityTokenType {
        COUPON,
        STRIP
    }

    /**
     * @dev Struct which represents the immutable data in the Token. Once set it cannot be modified.
     * @param baseCurrency the baseCurrency is the FIAT denomination of the digital security, this is the currency the `FrictionlessOnChainAssetToken` is issued in.
     * @param tokenType the type of the token as defined in the enum
     * @param onChainAssetAddress the address of the `FrictionlessOnChainAssetToken` for which this token is a future cash distribution.
     */
    struct FDSImmutableData {
        string baseCurrency;
        FrictionlessDigitalSecurityTokenType tokenType;
        address onChainAssetAddress;
    }

    /**
     * @dev Struct which represents the updatable data in the Token. This data can be modified by the Agent only.
     * @param maturesOn the maturity date of the digital security, it can be updated if there are delays in payment or at the request of the calculating agent.
     */
    struct FDSMutableData {
        uint256 maturesOn;
    }

    /// @dev error throw if there is an attempt to modify the immutable data.
    error FrictionlessDigitalSecurityTokenInitDataHasAlreadyBeenSet();

    /// @dev error throw if there is an attempt to set zero decimals.
    error FrictionlessDigitalSecurityTokenZeroDecimals();

    /**
     * @dev Sets the immutable data for the `FrictionlessDigitalSecurityToken`
     * @param initData the immutable data for the `FrictionlessDigitalSecurityToken`
     */
    function setInitData(FDSImmutableData calldata initData) external;

    /**
     * @dev Sets the updatable data for the `FrictionlessDigitalSecurityToken`
     * @param mutableData the updatable data for the `FrictionlessDigitalSecurityToken`
     */
    function setUpdateData(FDSMutableData calldata mutableData) external;

    /**
     * @dev Sets the custodian URI for the token
     * @param custodianURI the custodian URI for the token
     */
    function setCustodianURI(string calldata custodianURI) external;

    /**
     * @dev Sets the decimals value for the token
     * @param decimals the decimals value for the token
     */
    function setDecimals(uint8 decimals) external;

    /**
     * @dev Get the baseCurrency is the FIAT denomination of the digital security, this is the currency the `FrictionlessOnChainAssetToken` is issued in.
     * @return the baseCurrency is the FIAT denomination of the digital security, this is the currency the `FrictionlessOnChainAssetToken` is issued in.
     */
    function getCurrency() external view returns (string memory);

    /**
     * @dev Get the type of the token as defined in the enum `FrictionlessDigitalSecurityTokenType`.
     * @return the type of the token as defined in the enum.
     */
    function getTokenType() external view returns (FrictionlessDigitalSecurityTokenType);

    /**
     * @dev Get the onChainAssetAddress the address of the `FrictionlessOnChainAssetToken` for which this token is a future cash distribution.
     * @return onChainAssetAddress the address of the `FrictionlessOnChainAssetToken` for which this token is a future cash distribution.
     */
    function getOnChainAssetAddress() external view returns (address);

    /**
     * @dev Get the maturity date of the digital security.
     * @return the maturity date of the digital security.
     */
    function getMaturesOn() external view returns (uint256);

    /**
     * @dev Returns the custodian URI of the token
     */
    function custodianURI() external view returns (string memory);
}