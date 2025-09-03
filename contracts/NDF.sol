// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IERC6123.sol";
import "./assets/SwapToken.sol";
import "./NDFStorage.sol";
import "./test/IRates.sol";
import "./assets/ERC3643/interfaces/Frictionless/IFrictionlessFXSwap.sol";

contract NDF is IERC6123, NDFStorage, SwapToken {
    constructor(
        string memory _tradeId,
        Types.IRS memory _irs,
        address _frictionlessTreasury,
        uint256 _initialMargin,
        uint256 _maintenanceMargin,
        uint256 _terminationFee,
        uint256 _confirmationTime,
        Types.SettlementType _settlementType,
        address _ratesContractAddress,
        address _exchangePriceFeedAddress,
        uint256 exchangePriceDecimals
    ) SwapToken(_irs.settlementCurrency) {
        irs = _irs;
        frictionlessTreasury = _frictionlessTreasury;
        tradeId = _tradeId;
        initialMargin = _initialMargin;
        maintenanceMargin = _maintenanceMargin;
        terminationFee = _terminationFee;
        confirmationTime = _confirmationTime;
        settlementType = _settlementType;
        ratesContractAddress = _ratesContractAddress;
        exchangePriceDecimals = exchangePriceDecimals;
        exchangePriceFeed = AggregatorV3Interface(_exchangePriceFeedAddress);
    }

    function inceptTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyCounterparty onlyWhenTradeInactive onlyBeforeMaturity returns (string memory) {
        address inceptor = msg.sender;

        if(_withParty == address(0)) revert InvalidPartyAddress(_withParty);
        if(inceptor == _withParty) revert cannotInceptWithYourself(inceptor, _withParty);
        if(_withParty != irs.longParty || inceptor != irs.shortParty) revert InvalidPartyAddress(_withParty);
        if(_position != 1 || _position != -1) revert InvalidPosition(_position);
        if(_position == 1) require(inceptor == irs.longParty, "NDF: Inceptor must be party A");
        if(_position == -1) require(inceptor == irs.shortParty, "NDF: Inceptor must be party B");

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
            IToken(irs.settlementCurrency).transferFrom(inceptor, address(this), upfrontPayment),
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
            IToken(irs.settlementCurrency).transferFrom(msg.sender, address(this), marginAndFee),
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
        tradeState = Types.TradeState.Matured;

        require(
            IToken(irs.settlementCurrency).transfer(irs.longParty, netSettlementAmount),
            "NDF: Transfer to party A failed"
        );

        emit SettlementEvaluated(msg.sender, _settlementAmount, _settlementData);
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

        emit TradeTerminationRequest(msg.sender, _tradeId, _terminationPayment, _terminationTerms);
    }

    ///////========> COMPLETE THE PAYMENT LOGIC WHEN THE TREASURY CONTRACT IS AVAILABLE <========////////
    function confirmTradeTermination(
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

        address requester = pendingRequests[terminationHash];
        if (requester == msg.sender) revert InvalidPartyAddress(requester);

        delete pendingRequests[terminationHash];
        tradeState = Types.TradeState.Terminated;

        // Transfer the termination payment to the caller
        uint256 terminationFees = marginRequirements[requester].terminationFee;
        uint256 scale = _getPaymentTokenDecimalScale();
        uint256 termsinationAmount = terminationFees * scale;
        marginRequirements[requester].terminationFee = 0;
        require(
            IToken(irs.settlementCurrency).transfer(msg.sender, termsinationAmount),
            "NDF: Transfer of termination amount failed"
        );

        emit TradeTerminated(requester, _tradeId, _terminationPayment, _terminationTerms);
    }

    function cancelTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external override onlyWhenSettled onlyBeforeMaturity {
        uint256 terminationHash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        address requester = pendingRequests[terminationHash];
        if (pendingRequests[terminationHash] != msg.sender) revert InvalidAddressOrTradeData(msg.sender, terminationHash);

        delete pendingRequests[terminationHash];
        tradeState = Types.TradeState.Settled;    // NOT CLEAR: Should it be `Settled` or `Active`?

        emit TradeTerminationCancelled(requester, _tradeId, _terminationPayment, _terminationTerms);
    }

    /**
    * @notice This function is used to evaluate the margin requirements
    *         and update the margin balances of the parties involved.
    */
    function evaluateMargin() external onlyWhenTradeConfirmed onlyBeforeMaturity {
        require(
            msg.sender == marginEvaluationUpkeepAddress,
            "NDF: Only the margin evaluation upkeep can call this function"
        );

        uint256 partyASwapAmount = _updateSpotRate(irs.partyACollateralCurrency);
        uint256 partyBSwapAmount = _updateSpotRate(irs.partyBCollateralCurrency);

        if(partyASwapAmount == partyBSwapAmount) {
            emit MarginCall(longParty, shortParty, 0, partyASwapAmount, partyBSwapAmount, block.timestamp);
        } else if(partyASwapAmount > partyBSwapAmount) {
            uint256 currentMargin = margin[irs.longParty].currentMargin;
            uint256 netAmount = partyASwapAmount - partyBSwapAmount;
            margin[irs.longParty].currentMargin = currentMargin + netAmount;

            emit MarginCall(irs.longParty, irs.shortParty, netAmount, partyASwapAmount, partyBSwapAmount, block.timestamp);
        } else {
            uint256 netAmount = partyBSwapAmount - partyASwapAmount;
            uint256 currentMargin = margin[irs.shortParty].currentMargin;
            margin[irs.shortParty].currentMargin = currentMargin + netAmount;

            emit MarginCall(irs.shortParty, irs.longParty, netAmount, partyBSwapAmount, partyASwapAmount, block.timestamp);
        }
    }

    /**
    * @notice This function is used to top up the margin balance of a party.
    *         The party can call this function to add funds to their margin account.
    */
    function topUpMargin() external onlyCounterparty onlyWhenTradeConfirmed onlyBeforeMaturity {
        uint256 topUpAmount = margin[msg.sender].currentMargin;
        if(topUpAmount == 0) revert NoMarginNeeded();

        margin[msg.sender].currentMargin = 0;
        margin[msg.sender].totalMarginPosted += topUpAmount;
        require(
            IToken(irs.settlementCurrency).transferFrom(msg.sender, address(this), topUpAmount),
            "NDF: Transfer of top-up amount failed"
        );

        emit MarginTopUp(msg.sender, topUpAmount, block.timestamp);
    }

    /**
    * @notice This function is used to settle the trade at maturity.
    *         It can be called by the settlement automated contract.
    */
    function settle() external onlyAfterMaturity {
        require(
            msg.sender == settlementUpkeepAddress,
            "NDF: Only the settlement upkeep can call this function"
        );

        uint256 partyASwapAmount = _updateSpotRate(irs.partyACollateralCurrency);
        uint256 partyBSwapAmount = _updateSpotRate(irs.partyBCollateralCurrency);
        uint256 netSettlementAmount;

        if(partyASwapAmount == partyBSwapAmount) {
            tradeState = Types.TradeState.Settled;
            _generateSettlementReceipt(0, partyASwapAmount, partyBSwapAmount);
            return;
        } else if(partyASwapAmount > partyBSwapAmount) {
            netSettlementAmount = partyASwapAmount - partyBSwapAmount;
            payerParty = irs.longParty;
            _generateSettlementReceipt(netSettlementAmount, partyASwapAmount, partyBSwapAmount);

            uint256 totalMargin = margin[payerParty].totalMarginPosted;
            margin[payerParty].totalMarginPosted = totalMargin - netSettlementAmount;
            performSettlement(int256(netSettlementAmount), tradeId);
        } else if(partyBSwapAmount > partyASwapAmount) {
            netSettlementAmount = partyBSwapAmount - partyASwapAmount;
            payerParty = irs.shortParty;
            _generateSettlementReceipt(netSettlementAmount, partyASwapAmount, partyBSwapAmount);

            uint256 totalMargin = margin[payerParty].totalMarginPosted;
            margin[payerParty].totalMarginPosted = totalMargin - netSettlementAmount;
            performSettlement(int256(netSettlementAmount), tradeId);
        }
    }

    function setFrictionlessFXSwapAddress(address _frictionlessFXSwapAddress) external onlyCounterparty {
        if(_frictionlessFXSwapAddress == address(0)) revert InvalidAddress(_frictionlessFXSwapAddress);
        frictionlessFXSwapAddress = _frictionlessFXSwapAddress;
    }

    function setMarginEvaluationUpkeepAddress(address _marginEvaluationUpkeepAddress) external onlyCounterparty {
        if(_marginEvaluationUpkeepAddress == address(0)) revert InvalidAddress(_marginEvaluationUpkeepAddress);
        marginEvaluationUpkeepAddress = _marginEvaluationUpkeepAddress;
    }

    /**
    * @dev Calculates the FX swap amount for a given Party based on the notional amount.
    * This is used to determine the amount of settlement currency that Party will swap
    * in the FX swap transaction.
    * @return fxSwapAmount amount that must be paid by the given Party to the other Party.
    */
    function _updateSpotRate(address _partyCollateralCurrency) private view returns (uint256 fxSwapAmount) {
        uint256 scale = _getPaymentTokenDecimalScale();
        uint256 notional = irs.notionalAmount * scale;

        if(_partyCollateralCurrency == irs.settlementCurrency) {
            fxSwapAmount = notional;
        } else {
            uint256 exchangeRate = IRates(ratesContractAddress).getRate();
            uint256 rateDecimals = IRates(ratesContractAddress).decimals();
            uint256 rateScale = 10 ** rateDecimals;
            fxSwapAmount = (notional * exchangeRate) / rateScale;

            IFrictionlessFXSwap(frictionlessFXSwapAddress).swapTokens(
                _partyCollateralCurrency,
                irs.settlementCurrency,
                payerParty,
                address(this),
                notional,
                exchangeRate
            );
            /** Chainlink Price Feed logic to be implemented
            int256 latestRate;
            (,latestRate,,,) = exchangePriceFeed.latestRoundData();
            uint256 exchangeRate = uint256(latestRate);
            fxSwapAmount = (notional * exchangeRate)/ (10 ** exchangePriceDecimals);
             */
        }
    }

    function _generateSettlementReceipt(
        uint256 _settlementAmount,
        uint256 _partyAPaymentAmount,
        uint256 _partyBPaymentAmount
    ) internal {
        receipts.push(Types.Receipt({
            from: payerParty,
            to: otherParty(payerParty),
            netAmount: _settlementAmount,
            timestamp: block.timestamp,
            conversionRate: currentExchangeRate,
            partyAPaymentAmount: _partyAPaymentAmount,
            partyBPaymentAmount: _partyBPaymentAmount
        }));
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
        return frictionlessTreasury;
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

    function getSettlementType() external view returns (Types.SettlementType) {
        return settlementType;
    }

    function getConfirmationTime() external view returns (uint256) {
        return confirmationTime;
    }

    function getMarginEvaluationUpkeepAddress() external view returns (address) {
        return marginEvaluationUpkeepAddress;
    }

    function getSettlementUpkeepAddress() external view returns (address) {
        return settlementUpkeepAddress;
    }

    function getFrictionlessTreasury() external view returns (address) {
        return frictionlessTreasury;
    }

    function getFrictionlessFXSwapAddress() external view returns (address) {
        return frictionlessFXSwapAddress;
    }

    function getExchangePriceFeed() external view returns (address) {
        return address(exchangePriceFeed);
    }

    function getCurrentExchangeRate() external view returns (uint256) {
        return currentExchangeRate;
    }

    function getExchangePriceDecimals() external view returns (uint256) {
        return exchangePriceDecimals;
    }

    function getRatesContractAddress() external view returns (address) {
        return ratesContractAddress;
    }

    function getPayerParty() external view returns (address) {
        return payerParty;
    }

    function getNetSettlementAmount() external view returns (uint256) {
        return netSettlementAmount;
    }

    function getReceipts() external view returns (Types.Receipt[] memory) {
        return receipts;
    }

    function otherParty() internal view returns(address) {
        return msg.sender == irs.longParty ? irs.shortParty : irs.longParty;
    }

    function otherParty(address _account) internal view returns(address) {
        return _account == irs.longParty ? irs.shortParty : irs.longParty;
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