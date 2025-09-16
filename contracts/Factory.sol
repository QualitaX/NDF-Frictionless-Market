// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Types.sol";
import "./FXForward.sol";

contract Factory {
    struct Deployed {
        string tradeID;
        address contractAddress;
    }

    error alreadyDeployed(string tradeID); 

    mapping(string => bool) public isDeployed;
    Deployed[] internal deployedContracts;

    event ContractDeployed(string tradeID, address deployer, address contractAddress);

    function deployForwardContract(
        string memory _tradeId,
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        uint256 _initialMargin,
        uint256 _terminationFee,
        Types.SettlementType _settlementType,
        address _ratesContractAddress,
        address _frictionlessFXSwapAddress
    ) external {
        if (isDeployed[_tradeId]) revert alreadyDeployed(_tradeId);

        FXForward forwardContract = new FXForward{salt: bytes32(abi.encodePacked(_tradeId))}(
            _tradeId,
            _irsTokenName,
            _irsTokenSymbol,
            _irs,
            _initialMargin,
            _terminationFee,
            _settlementType,
            _ratesContractAddress,
            _frictionlessFXSwapAddress
        );

        deployedContracts.push(Deployed({
            tradeID: _tradeId,
            contractAddress: address(forwardContract)
        }));
        isDeployed[_tradeId] = true;

        emit ContractDeployed(_tradeId, msg.sender, address(forwardContract));
    }

    function getDeployedContracts() external view returns (Deployed[] memory) {
        return deployedContracts;
    }
}