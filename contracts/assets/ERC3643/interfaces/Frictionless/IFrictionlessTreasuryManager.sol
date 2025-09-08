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
import { IFrictionlessDigitalSecurityToken } from "./IFrictionlessDigitalSecurityToken.sol";
import { IFrictionlessFundDepositToken } from "./IFrictionlessFundDepositToken.sol";
import { IFrictionlessOnChainAssetToken } from "./IFrictionlessOnChainAssetToken.sol";

/**
 * @title IFrictionlessTreasuryManager - Manages the minting, transfer and burning of all tokens in the Frictionless protocol
 * @author Frictionless Group Holdings S.à.r.l
 * @notice The IFrictionlessTreasuryManager is responsible for all token operations, minting, transferring and burning in
 * the Frictionless protocol. The tokens and their lifecycles are defined in the public README for the Frictionless protocol at
 * https://gitlab.com/dfyclabs/protocol/dfyclabs-tokens/-/tree/main?ref_type=heads#tokens-overview
 */
interface IFrictionlessTreasuryManager {
    /**
     * @dev Structure that encapsulates both the implAuthority and the compliance for the specific token.
     * @param implAuthority the contract address for the implementation authority associated with the specific Frictionless token type.
     * @param tokenType the Frictionless token type as specified by the enumeration `IBasicFrictionlessToken.FrictionlessTokenTypes`
     */
    struct FrictionlessTokenInitData {
        address implAuthority;
        IBasicFrictionlessToken.FrictionlessTokenTypes tokenType;
    }

    /// @dev throws if specific address is zero.
    error FrictionlessIsZeroAddress(string);

    /**
     * @dev Event emitted when a `FrictionlessFundDeposit`, `FrictionlessDigitalSecurity` or `FrictionlessOnChainAsset` is minted.
     * @param token the address of the token minted
     * @param tokenName the name of the token
     * @param tokenSymbol the token symbol
     * @param amount the amount of the token minted
     * @param toAddress the address the token was minted to
     */
    event FrictionlessTokenMinted(
        IBasicFrictionlessToken.FrictionlessTokenTypes tokenType,
        address token,
        string tokenName,
        string tokenSymbol,
        uint256 amount,
        address toAddress
    );

    /**
     * @dev Event emitted when a `FrictionlessFundDeposit`, `FrictionlessDigitalSecurity` or `FrictionlessOnChainAsset` is transferred.
     * @param token the address of the token transferred
     * @param amount the amount of the token transferred
     * @param fromAddress the address the token was transferred from
     * @param toAddress the address the token was transferred to
     */
    event FrictionlessTokenTransferred(
        IBasicFrictionlessToken.FrictionlessTokenTypes tokenType,
        address token,
        uint256 amount,
        address fromAddress,
        address toAddress
    );

    /**
     * @dev Event emitted when a `FrictionlessFundDeposit`, `FrictionlessDigitalSecurity` or `FrictionlessOnChainAsset` is burned.
     * @param token the address of the token burned
     * @param amount the amount of the token burned
     * @param fromAddress the address the token was burned from
     */
    event FrictionlessTokenBurned(
        IBasicFrictionlessToken.FrictionlessTokenTypes tokenType,
        address token,
        uint256 amount,
        address fromAddress
    );

    /// @dev error throw if the function caller is not a PROTOCOL_TREASURY address. Thrown during the `mintFundDepositForTreasury`
    error FrictionlessTreasuryManagerNotAProtocolTreasury(address);

    /// @dev error throw if the FundDepositToken for specified currency and fundIBAN already exists
    error FrictionlessTreasuryManagerFundDepositTokenAlreadyExists(string currency, string fundIBAN);

    /// @dev error throw if the data for the token init data `FrictionlessTokenInitData` is invalid. Thrown during the `_setTokensInitData`
    error FrictionlessTreasuryManagerInvalidTokenInitData(FrictionlessTokenInitData);

    /// @dev error throw if the data for the token init data `FrictionlessTokenInitData` is already set. Thrown during the `_setTokensInitData`
    error FrictionlessTreasuryManagerUnableToUpdateTokenInitData(IBasicFrictionlessToken.FrictionlessTokenTypes);

    /// @dev error throw if the data for the IFrictionlessFundDepositToken is invalid. Thrown during the `mintFundDepositForTreasury`
    error FrictionlessTreasuryManagerInvalidDepositData(IFrictionlessFundDepositToken.FFDImmutableData);

    /// @dev error throw if the data for the IFrictionlessDigitalSecurityToken is invalid. Thrown during the `mintDigitalSecurity`
    error FrictionlessTreasuryManagerInvalidFDSImmutableData(IFrictionlessDigitalSecurityToken.FDSImmutableData);

    /// @dev error throw if the data for the IFrictionlessDigitalSecurityToken is invalid. Thrown during the `mintOnChainAsset`
    error FrictionlessTreasuryManagerInvalidFOCASpecData(IFrictionlessOnChainAssetToken.FOCASpecData);

    /// @dev error throw if the data for the IFrictionlessDigitalSecurityToken is invalid. Thrown during the `mintOnChainAsset`
    error FrictionlessTreasuryManagerInvalidFOCAIssuanceData(IFrictionlessOnChainAssetToken.FOCAIssuanceData);

    /**
     * @dev See {PausableUpgradeable-_pause}
     */
    function pause() external;

    /**
     * @dev See {PausableUpgradeable-_unpause}
     */
    function unpause() external;

    /**
     * @dev Sets and associates the implementation authority with the associated token type
     * @param initDataArr_ the `FrictionlessTokenInitData` configuration associating the implementation authority with the associated token type.
     */
    function setTokensInitData(FrictionlessTokenInitData[] calldata initDataArr_) external;

    /**
     * @dev Mints a Fund Deposit Token in the specified currency/IBAN pair. This function is invoked to create the genesis mint of the
     * deposit token in the PROTOCOL_TREASURY.
     * @param depositData the immutable deposit data for the token
     * @param treasuryAddress the address of the treasury, which receives the deposit tokens
     * @param amount the amount of tokens
     * @return address of the token minted
     * emits `FrictionlessTokenMinted` event
     * throws error `FrictionlessTreasuryManagerInvalidDepositData` if the deposit data is invalid.
     * requires the depositData.currency to be a 3 letter currency code
     * requires the depositData.description to be not empty
     * requires the depositData.IBAN to be not empty
     */
    function mintFundDepositForTreasury(
        IFrictionlessFundDepositToken.FFDImmutableData calldata depositData,
        address treasuryAddress,
        uint256 amount
    ) external returns (address);

    /**
     * @dev Mints a FrictionlessDigitalSecurityToken as the future dated cash distribution from the underlying FrictionlessOnChainAssetToken.
     * This function is invoked to create the genesis mint of the deposit token in the PROTOCOL_TREASURY.
     * @param initData the immutable data for the token
     * @param updateData the mutable data for the token
     * @param amount the amount of tokens
     * @param userAddress the address of the protocol user, which receives the digital security tokens
     * @return address of the token minted
     * emits `FrictionlessTokenMinted` event
     * throws error `FrictionlessTreasuryManagerInvalidFDSImmutableData` if the initData is invalid.
     * requires the initData.currency to be a 3 letter currency code
     * requires the initData.onChainAssetAddress to be non 0 address
     */
    function mintDigitalSecurity(
        IFrictionlessDigitalSecurityToken.FDSImmutableData memory initData,
        IFrictionlessDigitalSecurityToken.FDSMutableData memory updateData,
        uint256 amount,
        address userAddress
    ) external returns (address);

    /**
     * @dev Mints a FrictionlessOnChainAssetToken as the representation of the asset to be securitized, fractionalized & sold.
     * This function is invoked to create the genesis mint of the deposit token to the PERMISSIONED_CUSTODIAN.
     * @param specData the immutable data for the token
     * @param issuanceData the issuance data for the token
     * @param updateData the update data for the token
     * @param custodianAddress the address of the protocol custodian, which receives the `FrictionlessOnChainAssetToken`
     * @return address of the token minted
     * emits `FrictionlessTokenMinted` event
     * throws error `FrictionlessTreasuryManagerInvalidFOCASpecData` or `FrictionlessTreasuryManagerInvalidFOCAIssuanceData` if the specData or issuanceData is invalid.
     */
    function mintOnChainAsset(
        IFrictionlessOnChainAssetToken.FOCASpecData memory specData,
        IFrictionlessOnChainAssetToken.FOCAIssuanceData memory issuanceData,
        IFrictionlessOnChainAssetToken.FOCAUpdateData memory updateData,
        address custodianAddress
    ) external returns (address);

    /**
     * @dev Used to increase the mint of a Frictionless token which already exists.
     * @param token the address of the token
     * @param userAddress the address to min the token to
     * @param amount the amount of tokens to mint
     * emits `FrictionlessTokenMinted` event
     */
    function mintTokenForUser(address token, address userAddress, uint256 amount) external;

    /**
     * @dev Used to increase the mint of a Frictionless token which already exists.
     * @param token the address of the token
     * @param userAddressFrom the address to transfer the tokens from
     * @param userAddressTo the address to transfer the tokens to
     * @param amount the amount of tokens to mint
     * emits `FrictionlessTokenTransferred` event
     */
    function transferToken(address token, address userAddressFrom, address userAddressTo, uint256 amount) external;

    /**
     * @dev Used to burn an amount of Frictionless token which already exists.
     * @param token the address of the token
     * @param userAddress the address to burn the tokens from
     * @param amount the amount of tokens to burn
     * emits `FrictionlessTokenBurned` event
     */
    function burnToken(address token, address userAddress, uint256 amount) external;

    /**
     * @dev returns the address of the fund deposit token by currency and fundIBAN
     * @param currency_ the currency of the fund deposit token
     * @param fundIBAN_ the fundIBAN of the fund deposit token
     * @return the address of the fund deposit token for specified currency and fundIBAN
     */
    function getFundDepositToken(string calldata currency_, string calldata fundIBAN_) external view returns (address);

    /**
     * @dev returns fund deposit token key by currency and fundIBAN
     * @param currency_ the currency of the fund deposit token you need
     * @param fundIBAN_ the fundIBAN of the fund deposit token you need
     * @return the fund deposit token key
     */
    function getFundDepositTokenKey(string memory currency_, string memory fundIBAN_) external pure returns (bytes32);
}