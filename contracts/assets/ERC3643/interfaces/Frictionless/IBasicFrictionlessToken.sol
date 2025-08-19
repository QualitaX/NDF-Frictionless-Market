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

import { IToken } from "../IToken.sol";

/**
 * @title IBasicFrictionlessToken - Represents the base interface for Frictionless protocol tokens.
 * @author Frictionless Group Holdings S.à.r.l
 * @notice The IBasicFrictionlessToken Represents the base interface for Frictionless protocol tokens, this interface is used to determine a token type.
 */
interface IBasicFrictionlessToken is IToken {
    /**
     * @dev Enumeration to represent each of the tokens in the Frictionless protocol.
     */
    enum FrictionlessTokenTypes {
        NONE,
        FUND_DEPOSIT_TOKEN, // IFrictionlessFundDepositToken
        DIGITAL_SECURITY_TOKEN, // IFrictionlessDigitalSecurityToken
        ON_CHAIN_ASSET_TOKEN // IFrictionlessOnChainAssetToken
    }

    /// @dev error thrown if an attempt to set an invalid token type during function `setFrictionlessTokenType`
    error BasicFrictionlessTokenUnableToUpdateFrictionlessTokenType();

    /**
     * @dev Sets the token type according to the specified enumeration
     * @param newTokenType_ the token type to set
     */
    function setFrictionlessTokenType(FrictionlessTokenTypes newTokenType_) external;

    /**
     * @dev Returns the token type according to the specified enumeration
     * @return FrictionlessTokenTypes the token type according to the specified enumeration
     */
    function getFrictionlessTokenType() external view returns (FrictionlessTokenTypes);
}