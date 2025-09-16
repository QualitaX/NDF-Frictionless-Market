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

import { IAbstractFeeModule } from "./abstract/IAbstractFeeModule.sol";
import { IFrictionlessTreasuryManager } from "./IFrictionlessTreasuryManager.sol";
import { IFrictionlessPermissionsManager } from "./IFrictionlessPermissionsManager.sol";

/**
 * @title IFrictionlessFXSwap - Interface defining the frictionless conversion and atomic swapping of any `FrictionlessFundDepositToken` currency pair on the Frictionless protocol.
 * @author Frictionless Group Holdings S.à.r.l
 * @notice Interface defining the frictionless conversion and atomic swapping of any `FrictionlessFundDepositToken` currency pair on the Frictionless protocol.
 * The FX rates are set from the live spot & forward FX partners on the protocol.
 */
interface IFrictionlessFXSwap is IAbstractFeeModule {
    /**
     * @dev Structure representing token fee information including the token address and fee information
     * @param tokenAddr The address of the token
     * @param feeAbsoluteLimit The absolute limit of fees to be paid in the FX
     * @param feeInfo The fee information associated with the token
     */
    struct FrictionlessTokenFXFeeInfo {
        address tokenAddr;
        uint256 feeAbsoluteLimit;
        FeeInfo feeInfo;
    }

    /**
     * @dev Event emitted upon successful token swaps
     * @param sellingTokenAddr The address of the token being sold
     * @param buyingTokenAddr The address of the token being bought
     * @param tokenSender The address of the sender initiating the swap
     * @param tokenRecipient The address of the recipient receiving the bought tokens
     * @param sellingTokensAmount The amount of tokens being sold
     * @param buyingTokensAmount The amount of tokens being bought
     * @param buyingTokenExchangeRate The exchange rate of the token being bought to the token being sold
     */
    event FrictionlessFXTokensSwapped(
        address sellingTokenAddr,
        address buyingTokenAddr,
        address tokenSender,
        address tokenRecipient,
        uint256 sellingTokensAmount,
        uint256 buyingTokensAmount,
        uint256 buyingTokenExchangeRate
    );

    /// @dev error thrown during `setSwapFees` if token adresses are invalid (zero addresses, equals addresses and etc.).
    error FrictionlessFXSwapInvalidTokenAddresses(address token0, address token1);

    /// @dev error thrown during `setSwapFees`, `setTokenFee` and `swapTokens` if the fxDeskFeeRecipient doesn't equal to the stored `fxDeskFeeAddr`
    error FrictionlessFXSwapInvalidFeeRecipientAddr(address newFeeRecipient);

    /// @dev error thrown during `swapTokens` if the msg.sender is not a PROTOCOL_TREASURY.
    error FrictionlessFXSwapNotEnoughPermissions();

    /**
     * @dev Sets the address of the FXDesk fee recipient
     * Only Owner (PROTOCOL_ADMIN) can call this function
     * @param newFXDeskFeeAddr_ The new address of the FXDesk fee recipient
     */
    function setFXDeskFeeAddr(address newFXDeskFeeAddr_) external;

    /**
     * @dev Set the swap fees for the swaps of a token pair. The fees can be any combination of zero (0%) or upto 10000 bps (100%) on any directional transfer.
     * Fees can only be set by the Owner (PROTOCOL_ADMIN).
     * @param token0FeeInfo_ The fees associated with the token0 (first token) in the token pair during the swap.
     * @param token1FeeInfo_ The fees associated with the token1 (second token) in the token pair during the swap.
     * throws `FrictionlessFXSwapInvalidTokenAddresses` if the token addresses are invalid.
     * throws `FrictionlessFXSwapInvalidFeeRecipientAddr` if the feeRecipientAddr doesn't equal to the `fxDeskFeeAddr`.
     * throws `AbstractFeeModuleInvalidFeeRecipient` if the feeRecipientAddr is a zero address
     * throws `AbstractFeeModuleInvalidFee` if the feeInBps is not in the valid range (ZERO_FEES_IN_BPS to MAX_FEES_IN_BPS)
     * emits `FrictionlessFeeSet` upon completion of the setting of the fee info for the token in either set of fees
     */
    function setSwapFees(
        FrictionlessTokenFXFeeInfo calldata token0FeeInfo_,
        FrictionlessTokenFXFeeInfo calldata token1FeeInfo_
    ) external;

    /**
     * @dev Set the fee associated with the swap of a Token and manages the mapping of the key to this set of Fees.
     * Can only be set by the Owner (PROTOCOL_ADMIN).
     * @param tokenFeeKey_ The key, generated by the function `getTokenFeeKey`, which is used to map a specific swap polarity for tokens.
     * @param tokenFeeInfo_ The fees associated with the swap of token, used in the calculation and disbursement of fees during swap of a token pair.
     * throws `FrictionlessFXSwapInvalidTokenAddresses` if the token addresses are invalid.
     * throws `FrictionlessFXSwapInvalidFeeRecipientAddr` if the feeRecipientAddr doesn't equal to the `fxDeskFeeAddr`.
     * throws `AbstractFeeModuleInvalidFeeRecipient` if the feeRecipientAddr is a zero address
     * throws `AbstractFeeModuleInvalidFee` if the feeInBps is not in the valid range (ZERO_FEES_IN_BPS to MAX_FEES_IN_BPS)
     * emits `FrictionlessTokenFeeSet` upon completion of the setting of the fee info for the token
     */
    function setTokenFee(bytes32 tokenFeeKey_, FrictionlessTokenFXFeeInfo calldata tokenFeeInfo_) external;

    /**
     * @dev Swaps tokens between addresses at a specified exchange rate
     * Only PROTOCOL_TREASURY can call this function
     * @param sellingTokenAddr_ The address of the token to be sold
     * @param buyingTokenAddr_ The address of the token to be bought
     * @param tokenSender_ The address of the sender initiating the swap
     * @param tokenRecipient_ The address where the bought tokens will be sent
     * @param buyingTokensAmount_ The amount of tokens being bought
     * @param buyingTokenExchangeRate_ The exchange rate of the token being bought to the token being sold
     */
    function swapTokens(
        address sellingTokenAddr_,
        address buyingTokenAddr_,
        address tokenSender_,
        address tokenRecipient_,
        uint256 buyingTokensAmount_,
        uint256 buyingTokenExchangeRate_
    ) external;

    /**
     * @dev Retrieves the address of the FXDesk fee recipient
     * @return The address of the FXDesk fee recipient
     */
    function fxDeskFeeAddr() external view returns (address);

    /**
     * @dev Retrieves the Frictionless Treasury Manager contract
     * @return The address of the Frictionless Treasury Manager contract
     */
    function treasuryManager() external view returns (IFrictionlessTreasuryManager);

    /**
     * @dev Retrieves the Frictionless Permissions Manager contract
     * @return The address of the Frictionless Permissions Manager contract
     */
    function permissionManager() external view returns (IFrictionlessPermissionsManager);

    /**
     * @dev get the tokenFeeInfo set for the fees associated per token in an exchange.
     * @param token0_ the address of the first token in an exchange
     * @param token1_ the address of the second token in an exchange
     * @return FeeInfo set for the fees associated per token in an exchange.
     */
    function getSwapFeesInfo(address token0_, address token1_) external view returns (FeeInfo memory, FeeInfo memory);

    /**
     * @dev Generates keys based on the packed encoding of the addresses of sets of tokens using the keccak256 hashing function. Used to store tokenFees in mappings.
     * @param token0_ the address of the token 0 in a transfer fee calculation
     * @param token1_ the address of the token 1 in a transfer fee calculation
     * @return keys based on the packed encoding of the addresses of sets of tokens using the keccak256 hashing function.
     */
    function getSwapFeeKeys(address token0_, address token1_) external view returns (bytes32, bytes32);

    /**
     * @dev Generates a key based on the packed encoding of the addresses of both tokens using the keccak256 hashing function. Used to store tokenFees in mappings.
     * @param token0_ the address of the token 0 in a transfer fee calculation
     * @param token1_ the address of the token 1 in a transfer fee calculation
     * @return generates a key based on the packed encoding of the addresses of both tokens using the keccak256 hashing function.
     */
    function getTokenFeeKey(address token0_, address token1_) external view returns (bytes32);

    /**
     * @dev Calculates the amount of selling tokens based on the buying amount and exchange rate
     * @param buyingTokensAmount_ The amount of tokens being bought
     * @param buyingTokenExchangeRate_ The exchange rate of the token being bought to the token being sold
     * @return The amount of selling tokens
     */
    function getSellingTokensAmount(
        uint256 buyingTokensAmount_,
        uint256 buyingTokenExchangeRate_
    ) external view returns (uint256);
}
