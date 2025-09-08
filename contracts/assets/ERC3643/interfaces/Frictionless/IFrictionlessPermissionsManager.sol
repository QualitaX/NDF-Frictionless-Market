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

/**
 * @title IFrictionlessPermissionsManager - Manages the permission of participants in the Frictionless protocol
 * @author Frictionless Group Holdings S.à.r.l
 * @notice The IFrictionlessPermissionsManager is responsible for the management of permission of the various participants in
 * the Frictionless protocol. The roles and responsibilities are defined in the public README for the Frictionless protocol at
 * https://gitlab.com/dfyclabs/protocol/dfyclabs-tokens/-/blob/main/README.md?ref_type=heads#roles-responsibilities
 */
interface IFrictionlessPermissionsManager {
    /// @dev Enum of the Frictionless protocol participants.
    enum FrictionlessPermissionedUser {
        PROTOCOL_TREASURY,
        PERMISSIONED_CUSTODIAN,
        PERMISSIONED_INVESTOR,
        PERMISSIONED_MANAGER,
        PERMISSIONED_CALCULATING_AGENT,
        PERMISSIONED_TRANSFER_AGENT,
        PERMISSIONED_FUND_ACCOUNTANT
    }

    /// @dev throws if specific address is zero.
    error FrictionlessIsZeroAddress(string);

    /// @dev throws if treasury tries to add or remove treasury.
    error FrictionlessInvalidPermissionForTreasury();

    /// @dev throws if user is not a permissioned investor
    error FrictionlessUserIsNotPermssionedInvestor();

    /**
     * @dev Emitted when a user is added to the Frictionless protocol. This event is emitted by the `addUser` function.
     * @param userIdentity the address of the user's OnChainId (Identity)
     * @param userType the type of the user as per the enum
     * @param claimURI the URI of the off-chain claim for the user. i.e. The Frictionless Markets graphQL endpoint
     */
    event FrictionlessPermissionedUserAdded(address userIdentity, uint256 userType, string claimURI);

    /**
     * @dev Emitted when a user is registered in the Frictionless protocol. This event is emitted by the `registerIdentity` function.
     * @param userAddress the address of the user's wallet to register
     * @param userISOCountry the ISO 3166-1 numeric code of the user, can be the place of residence or the location KYC/AML onboarding was undertaken.
     */
    event FrictionlessPermissionedUserRegistered(address userAddress, uint16 userISOCountry);

    /**
     * @dev Emitted when a user is removed in the Frictionless protocol. This event is emitted by the `removeUser` function.
     * @param userAddress the address of the user's wallet to register
     */
    event FrictionlessPermissionedUserRemoved(address userAddress);

    /// @dev the internal struct defining a Claim for a PERMISSIONED_USER in the protocol. Used to submit claims for the OnChainId by the ClaimIssuer.
    struct Claim {
        address issuer;
        uint256 topic;
        uint8 scheme;
        address identity;
        bytes signature;
        bytes data;
    }

    /**
     * @dev Validates if a wallet address is permissioned in the Frictionless protocol
     * @param userAddress the wallet address to verify
     * @return true if the address is permissioned in the Frictionless Protocol.
     */
    function isPermissioned(address userAddress) external view returns (bool);

    /**
     * @dev Registers a users wallet address as an OnChainId (Identity) to the Frictionless protocol.
     * This Identity is used when permissioning a user to the protocol by invoking the addUser function later.
     * @param userAddress the address of the user's wallet to register
     * @param userISOCountry the ISO 3166-1 numeric code of the user, can be the place of residence or the location KYC/AML onboarding was undertaken.
     * requires The msg.sender to have the TREX Agent permissions (PROTOCOL_TREASURY or PROTOCOL_ADMIN)
     * @return address the address of the user's OnChainId (Identity) with the associated claims.
     */
    function registerIdentity(address userAddress, uint16 userISOCountry) external returns (address);

    /**
     * @dev Gets a users OnChainId (Identity) in the Frictionless protocol.
     * @param userAddress the address of the user's wallet to register
     * requires The msg.sender to have the TREX Agent permissions (PROTOCOL_TREASURY or PROTOCOL_ADMIN)
     * @return address the address of the user's OnChainId (Identity) with the associated claims.
     */
    function getIdentity(address userAddress) external returns (address);

    /**
     * @dev Get the signed claimData message to be used in the addUser function.
     * The message must be signed using the PK of the ClaimIssuer (PROTOCOL_ADMIN)
     * @param userIdentity the address of the user's OnChainId (Identity)
     * @param userType the type of the user as per the enum
     * @return signed claimData message to be used in the addUser unction once signed by the ClaimIssuer PK.
     */
    function getClaimMsgHash(
        address userIdentity,
        IFrictionlessPermissionsManager.FrictionlessPermissionedUser userType
    ) external view returns (bytes32);

    /**
     * @dev verify if the userAddress is permissioned in the Frictionless protocol and has a valid claim
     * @param userAddress the address of the user's wallet to verify
     * @param userType the type of the user as per the enum
     * @return true if a valid permissioned user and has a valid claim, otherwise false.
     */
    function hasClaim(address userAddress, FrictionlessPermissionedUser userType) external view returns (bool);

    /**
     * @dev Adds a user's OnChainId (Identity) to the Frictionless protocol along with its associated claim data.
     * The Identity is created by invoking the registerIdentity function first.
     * @param userIdentity the address of the user's OnChainId (Identity)
     * @param userType the type of the user as per the enum
     * @param claimSignature the signed claimData by the ClaimIssuer
     * @param claimURI the URI of the off-chain claim for the user. i.e. The Frictionless Markets graphQL endpoint
     * requires The msg.sender to be the Owner if the userType is the PROTOCOL_TREASURY
     * requires The msg.sender to have the TREX Agent permissions (PROTOCOL_TREASURY or PROTOCOL_ADMIN) to add any user
     * @return address the address of the user's OnChainId (Identity) with the associated claims.
     */
    function addUser(
        address userIdentity,
        FrictionlessPermissionedUser userType,
        bytes memory claimSignature,
        string memory claimURI
    ) external returns (address);

    /**
     * @dev Removes a user from the Frictionless protocol along with its associated claim data.
     * @param userAddress the address of the user's wallet
     * requires The msg.sender to have the TREX Agent permissions (PROTOCOL_TREASURY or PROTOCOL_ADMIN) to remove any user
     * @return true if the user is removed from the Frictionless protocol along with its associated claim data, otherwise false.
     */
    function removeUser(address userAddress) external returns (bool);
}