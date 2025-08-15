// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IERC6123.sol";
import "./assets/SwapToken.sol";
import "./NDFStorage.sol";

contract NDF is IERC6123, NDFStorage, SwapToken {
    function inceptTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyCounterparty onlyWhenTradeIncepted onlyBeforeMaturity returns (string memory) {
        address inceptor = msg.sender;

        if(_withParty == address(0)) revert InvalidPartyAddress(_withParty);
        if(inceptor == _withParty) revert cannotInceptWithYourself(inceptor, _withParty);
        if(_withParty != irs.partyA || inceptor != irs.partyB) revert InvalidPartyAddress(_withParty);
        if(_position != 1 || _position != -1) revert InvalidPosition(_position);
        if(_position == 1) require(inceptor == irs.partyA, "NDF: Inceptor must be party A");
        if(_position == -1) require(inceptor == irs.partyB, "NDF: Inceptor must be party B");

        tradeState = Types.TradeState.Incepted;

        uint256 dataHash = uint256(keccak256(
            abi.encodePacked(
                inceptor,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));
        pendingRequests[dataHash] = inceptor;
        tradeDataHash = Strings.toString(dataHash);
        inceptionTime = block.timestamp;

        uint256 scale = _getPaymentTokenDecimalScale();
        marginRequirements[inceptor] = Types.MarginRequirement({
            marginBuffer: initialMargin * scale,
            terminationFee: terminationFee * scale
        });

        // Deposit the initial margin and termination fees
        uint256 marginAndFee = (initialMargin + terminationFee) * scale;
        uint256 upfrontPayment = uint256(_paymentAmount); 
        upfrontPayment = upfrontPayment * scale;
        if (upfrontPayment != marginAndFee) revert InvalidUpfrontPayment(upfrontPayment, marginAndFee);

        require(
            IToken(irs.settlementCurrency).transferFrom(inceptor, treasury, upfrontPayment),
            "NDF: Transfer of margin and fees failed"
        );

        emit TradeIncepted(
            inceptor,
            _withParty,
            tradeId,
            tradeDataHash,
            _position,
            _paymentAmount,
            _initialSettlementData
        );
    }

    function confirmTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted onlyWithinConfirmationTime {
        address inceptionParty = otherParty();

        uint256 dataHash = uint256(keccak256(
            abi.encodePacked(
                _withParty,
                msg.sender,
                _tradeData,
                -_position,
                -_paymentAmount,
                _initialSettlementData
            )
        ));
        if (pendingRequests[dataHash] != inceptionParty)
            revert InvalidInceptorOrTradeData(inceptionParty, dataHash);

        delete pendingRequests[dataHash];
        tradeState = Types.TradeState.Confirmed;

        uint256 scale = _getPaymentTokenDecimalScale();
        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMargin * scale,
            terminationFee: terminationFee * scale
        });

        // Deposit the initial margin and termination fees
        uint256 marginAndFee = (initialMargin + terminationFee) * scale;
        uint256 upfrontPayment = uint256(_paymentAmount); 
        upfrontPayment = upfrontPayment * scale;
        if (upfrontPayment != marginAndFee) revert InvalidUpfrontPayment(upfrontPayment, marginAndFee);

        require(
            IToken(irs.settlementCurrency).transferFrom(msg.sender, treasury, marginAndFee),
            "NDF: Transfer of margin and fees failed"
        );

        emit TradeConfirmed(msg.sender, tradeId);
    }

    function cancelTrade(
        address _withParty, 
        string memory _tradeData, 
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted onlyBeforeMaturity {
        address inceptor = msg.sender;

        uint256 dataHash = uint256(keccak256(
            abi.encodePacked(
                inceptor,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));
        if (pendingRequests[dataHash] != inceptor) revert InvalidInceptorOrTradeData(inceptor, dataHash);

        delete pendingRequests[dataHash];
        tradeState = Types.TradeState.Inactive;

        emit TradeCancelled(inceptor, tradeId);
    }

    /**
    * @notice We don't implement the `initiateSettlement` function since this is done automatically
    */
    function initiateSettlement() external {
        revert obseleteFunction();
    }

    function performSettlement(
        int256 _settlementAmount,
        string memory _settlementData
    ) external {

    }

    /**
    * @notice We don't implement the `afterTransfer` function since the transfer of the contract
    *         net present value is transferred in the `performSettlement function`.
    */
    function afterTransfer(
        bool _success,
        string memory _transactionData
    ) external {
        revert obseleteFunction();
    }

    /**-> NOT CLEAR: Why requesting trade termination after the trade has been settled ? */
    function requestTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external override onlyCounterparty onlyWhenSettled onlyBeforeMaturity {
        if(
            keccak256(abi.encodePacked(_tradeId)) != keccak256(abi.encodePacked(tradeId))
        ) revert invalidTrade(_tradeId);

        uint256 terminationHash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        pendingRequests[terminationHash] = msg.sender;

        emit TradeTerminationRequest(msg.sender, tradeID, _terminationPayment, _terminationTerms);
    }

    function confirmTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external override onlyCounterparty onlyWhenSettled onlyBeforeMaturity {
        if(
            keccak256(abi.encodePacked(_tradeId)) != keccak256(abi.encodePacked(tradeId))
        ) revert invalidTrade(_tradeId);

        

    }

    function cancelTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external {

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

    function getInceptionTime() external view returns (uint256) {
        return inceptionTime;
    }

    function getTradeDataHash() external view returns (string memory) {
        return tradeDataHash;
    }

    function otherParty() internal view returns(address) {
        return msg.sender == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }

    function otherParty(address _account) internal view returns(address) {
        return _account == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }

    /**
    * @dev Returns the decimal scale for the settlement currency.
    * This is used to ensure that all amounts are correctly scaled
    * according to the token's decimal places.
    */
    function _getPaymentTokenDecimalScale() private view returns (uint256) {
        uint256 decimal = IToken(irs.settlementCurrency).decimals();
        return 10 ** decimal;
    }
}