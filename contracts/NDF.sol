// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./interfaces/IERC6123.sol";
import "./assets/SwapToken.sol";
import "./NDFStorage.sol";

contract NDF is IERC6123, NDFStorage, SwapToken {
    function inceptTrade(
        address withParty,
        string memory tradeData,
        int position,
        int256 paymentAmount,
        string memory initialSettlementData
    ) external returns (string memory) {
        
    }

    function confirmTrade(
        address withParty,
        string memory tradeData,
        int position,
        int256 paymentAmount,
        string memory initialSettlementData
    ) external {

    }

    function cancelTrade(
        address withParty, 
        string memory tradeData, 
        int position, int256 paymentAmount, string memory initialSettlementData
    ) external {

    }

    function initiateSettlement() external {

    }

    function performSettlement(int256 settlementAmount, string memory settlementData) external {

    }

    function afterTransfer(bool success, string memory transactionData) external {

    }

    function requestTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external {

    }

    function confirmTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external {

    }

    function cancelTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external {

    }

    function getIRS() external view returns (Types.IRS memory) {
        return irs;
    }

    function getTradeState() external view returns (Types.TradeState) {
        return tradeState;
    }

    function getMargin(address party) external view returns (uint256) {
        return margin[party];
    }

    function getPendingRequest(uint256 requestId) external view returns (address) {
        return pendingRequests[requestId];
    }

    function getTreasury() external view returns (address) {
        return treasury;
    }

    function getTradeId() external view returns (string memory) {
        return tradeId;
    }

    function getInitialMargin() external view returns (uint256) {
        return initialMargin;
    }

    function getMaintenanceMargin() external view returns (uint256) {
        return maintenanceMargin;
    }

    function getTerminationFee() external view returns (uint256) {
        return terminationFee;
    }
}