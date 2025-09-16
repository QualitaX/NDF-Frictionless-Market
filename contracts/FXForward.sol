// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IERC6123.sol";
import "./assets/SwapToken.sol";
import "./NDFStorage.sol";
import "./test/IRates.sol";
import "./assets/ERC3643/interfaces/Frictionless/IFrictionlessFXSwap.sol";

/**
*  _tradeId: "EURUSDNDF-1756878523"
*  _irsTokenName: "EUR USD Forward"
*  _irsTokenSymbol: "EURUSDF"
*  _irs: ["0x4e877414eF8f33f520bEBC32EBe581dfFBB2A457", "0x174f538120d3c074e70e89869b5ACdaF3346AD13", "0xdB783ea7C0534dc7A0edb9De735C063bd02e4322", "0xdB783ea7C0534dc7A0edb9De735C063bd02e4322", "0x580FAC15FFE9b2DF937bCe58f686233e911e53D4", "0xdB783ea7C0534dc7A0edb9De735C063bd02e4322", 118500, 3000, 1758027240, 1758452400]
*  _initialMargin: 300
*  _terminationFee: 50
*  _confirmationTime: 86400
*  _settlementType: 0
*  _ratesContractAddress: 0x20fABdA6cf6b8D477F00f0cCBb96dD5D0fb8b5a6
*  _frictionlessFXSwapAddress: 0xe3a39a11066eD8e0c233c24959943ab30c7Aeb11
*/

contract FXForward is IERC6123, NDFStorage, SwapToken {
    modifier onlyCounterparty() {
        require(
            msg.sender == irs.longParty || msg.sender == irs.shortParty,
            "You are not a counterparty."
        );
        _;
    }

    modifier onlyAfterMaturity() {
        require(
            block.timestamp > irs.maturityDate,
            "Trade is not matured yet."
        );
        _;
    }

    constructor(
        string memory _tradeId,
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        uint256 _initialMargin,
        uint256 _terminationFee,
        Types.SettlementType _settlementType,
        address _ratesContractAddress,
        address _frictionlessFXSwapAddress
        //address _exchangePriceFeedAddress,
        //uint256 _exchangePriceDecimals
    ) SwapToken(_irsTokenName, _irsTokenSymbol, _irs) {
        currentExchangeRate = _irs.contractRate;
        tradeId = _tradeId;
        initialMargin = _initialMargin;
        terminationFee = _terminationFee;
        confirmationTime = 1 days;
        settlementType = _settlementType;
        ratesContractAddress = _ratesContractAddress;
        frictionlessFXSwapAddress = _frictionlessFXSwapAddress;
        //exchangePriceDecimals = _exchangePriceDecimals;
        //exchangePriceFeed = AggregatorV3Interface(_exchangePriceFeedAddress);
    }

    function inceptTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyCounterparty onlyWhenTradeInactive onlyBeforeMaturity returns (string memory) {
        address inceptor = msg.sender;

        require(_withParty != address(0), "Invalid party address");
        if(inceptor == _withParty) revert cannotInceptWithYourself(inceptor, _withParty);
        require(
            _withParty == irs.longParty || _withParty == irs.shortParty,
            "Wrong 'withParty' address, MUST BE the counterparty"
        );
        require(_position == 1 || _position == -1, "invalid position");
        if(_position == 1) require(inceptor == irs.longParty, "NDF: Inceptor must be party A");
        if(_position == -1) require(inceptor == irs.shortParty, "NDF: Inceptor must be party B");

        tradeState = Types.TradeState.Incepted;

        uint256 dataHash = uint256(keccak256(
            abi.encode(
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

        //uint256 scale = _scaleBaseCurrencyTokens();
        uint256 scale = _scaleTokens(irs.collateralCurrency); 

        marginRequirements[inceptor] = Types.MarginRequirement({
            marginBuffer: initialMargin * scale,
            terminationFee: terminationFee * scale
        });

        // Deposit the initial margin and termination fees
        uint256 marginAndFee = (initialMargin + terminationFee) * scale;
        uint256 upfrontPayment = uint256(_paymentAmount) * scale;
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

        return tradeDataHash;
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
            abi.encode(
                _withParty,
                msg.sender,
                _tradeData,
                -_position,
                -_paymentAmount,
                _initialSettlementData
            )
        ));
        if (pendingRequests[dataHash] != inceptionParty)
            revert InvalidAddressOrTradeData(inceptionParty, dataHash);

        delete pendingRequests[dataHash];
        tradeState = Types.TradeState.Confirmed;

         //uint256 scale = _scaleBaseCurrencyTokens();
        uint256 scale = _scaleTokens(irs.collateralCurrency);

        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMargin * scale,
            terminationFee: terminationFee * scale
        });

        // Deposit the initial margin and termination fees
        uint256 marginAndFee = (initialMargin + terminationFee) * scale;
        uint256 upfrontPayment = uint256(-_paymentAmount) * scale;
        if (upfrontPayment != marginAndFee) revert InvalidUpfrontPayment(upfrontPayment, marginAndFee); 

        require(
            IToken(irs.settlementCurrency).transferFrom(msg.sender, address(this), upfrontPayment),
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
        if (pendingRequests[dataHash] != inceptor) revert InvalidAddressOrTradeData(inceptor, dataHash);

        delete pendingRequests[dataHash];
        tradeState = Types.TradeState.Inactive;

        emit TradeCanceled(inceptor, tradeId);
    }

    /**
    * @notice We don't implement the `initiateSettlement` function since this is done automatically
    */
    function initiateSettlement() external pure {
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
    function afterTransfer(bool /**success*/, string memory /*transactionData*/) external pure {
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
        uint256 scale = _scaleTokens(irs.collateralCurrency);
        //uint256 scale = _scaleTokens(irs.settlementCurrency);
        uint256 termsinationAmount = terminationFees * scale;
        marginRequirements[requester].terminationFee = 0;

        require(
            IToken(irs.settlementCurrency).transfer(msg.sender, termsinationAmount),
            "NDF: Transfer of termination amount failed"
        );

        emit TradeTerminationConfirmed(msg.sender, _tradeId, int256(termsinationAmount), _terminationTerms);
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

        if (pendingRequests[terminationHash] != msg.sender) revert InvalidAddressOrTradeData(msg.sender, terminationHash);

        delete pendingRequests[terminationHash];
        tradeState = Types.TradeState.Settled;    // NOT CLEAR: Should it be `Settled` or `Active`?

        emit TradeTerminationCanceled(msg.sender, _tradeId, _terminationTerms);
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

        int256 _currentForwardMargin;
        int256 _contractForwardMargin;
        (payerParty, marginCallAmount, _currentForwardMargin, _contractForwardMargin) = _calculateMarginCall();
        
        if(marginCallAmount == 0) {
            return;
        } else {
            uint256 currentMargin = margin[payerParty].currentMargin;
            margin[payerParty].currentMargin = currentMargin + marginCallAmount;
            emit MarginCall(payerParty, otherParty(payerParty), int256(marginCallAmount), _currentForwardMargin, _contractForwardMargin, block.timestamp);
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
            IToken(irs.collateralCurrency).transferFrom(msg.sender, address(this), topUpAmount),
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

        uint256 rateDecimals = IRates(ratesContractAddress).decimals();
        uint256 rateScale = 10 ** rateDecimals;
        uint256 notional = irs.notionalAmount * _scaleTokens(irs.baseCurrency);

        uint256 settlementAmountInSpotCurrency = notional * uint256(currentExchangeRate) / rateScale;

        tradeState = Types.TradeState.Settled;
        _settleContract(notional, settlementAmountInSpotCurrency, uint256(currentExchangeRate));

        emit TradeSettled(notional, settlementAmountInSpotCurrency, currentExchangeRate, irs.contractRate, block.timestamp);
    }

    function setFrictionlessFXSwapAddress(address _frictionlessFXSwapAddress) external onlyCounterparty {
        if(_frictionlessFXSwapAddress == address(0)) revert InvalidAddress(_frictionlessFXSwapAddress);
        frictionlessFXSwapAddress = _frictionlessFXSwapAddress;
    }

    function setMarginEvaluationUpkeepAddress(address _marginEvaluationUpkeepAddress) external onlyCounterparty {
        if(_marginEvaluationUpkeepAddress == address(0)) revert InvalidAddress(_marginEvaluationUpkeepAddress);
        marginEvaluationUpkeepAddress = _marginEvaluationUpkeepAddress;
    }

    function setSettlementUpkeepAddress(address _settlementUpkeepAddress) external onlyCounterparty {
        if(_settlementUpkeepAddress == address(0)) revert InvalidAddress(_settlementUpkeepAddress);
        settlementUpkeepAddress = _settlementUpkeepAddress;
    }

    function _calculateMarginCall() private returns (address partyToCall, uint256 marginCallAmount, int256 currentForwardAmount, int256 contractForwardAmount) {
        int256 currentForwardRate = IRates(ratesContractAddress).getRate();
        uint256 rateDecimals = IRates(ratesContractAddress).decimals();
        uint256 rateScale = 10 ** rateDecimals;
        currentExchangeRate = currentForwardRate;

        uint256 notional = irs.notionalAmount * _scaleTokens(irs.baseCurrency);
        contractForwardAmount = getContractForwardAmount();
        currentForwardAmount = currentForwardRate * int256(notional) / int256(rateScale);

        int256 currentMarkToMarket = currentForwardAmount - contractForwardAmount;
        variationMargin = currentMarkToMarket - previousMarkToMarket;
        
        uint256 marginInBaseCurrency;
        if(variationMargin == 0) {
            partyToCall = address(0);
            marginCallAmount = 0;
        } else if(variationMargin > 0) {
            partyToCall = irs.shortParty;
            marginInBaseCurrency = uint256(variationMargin);
            marginCallAmount = _convertInCurrency(marginInBaseCurrency, currentForwardRate, irs.collateralCurrency);
        } else {
            partyToCall = irs.longParty;
            marginInBaseCurrency = uint256(-variationMargin);
            marginCallAmount = _convertInCurrency(marginInBaseCurrency, currentForwardRate, irs.collateralCurrency);
        }

        previousMarkToMarket = currentMarkToMarket;
    }

    function _settleContract(uint256 _settlementAmountInBaseCurrency, uint256 _settlementAmountInSpotCurrency, uint256 _exchangeRate) private {
        _generateSettlementReceipt(_settlementAmountInBaseCurrency, _settlementAmountInSpotCurrency, currentExchangeRate, irs.contractRate);

        uint8 decimal = decimals();
        burn(irs.longParty, 10**decimal);
        burn(irs.shortParty, 10**decimal);

        IFrictionlessFXSwap(frictionlessFXSwapAddress).swapTokens(
            irs.spotCurrency,
            irs.baseCurrency,
            irs.longParty,
            irs.shortParty,
            _settlementAmountInBaseCurrency,
            _exchangeRate
        );
    }

    function _convertInCurrency(uint256 _amount, int256 _exchangeRate, address _currencyAddress) private view returns (uint256) {
        if(_currencyAddress == irs.baseCurrency) {
            return _amount;
        } else {
            uint256 rateDecimals = IRates(ratesContractAddress).decimals();
            uint256 rateScale = 10 ** rateDecimals;
            return (_amount * uint256(_exchangeRate)) / rateScale;
        }
    }

    function _generateSettlementReceipt(
        uint256 _amountInBaseCurrency,
        uint256 _amountInSpotCurrency,
        int256 _currentExchangeRate,
        int256 _contractRate
    ) private {
        receipts.push(Types.Receipt({
            settlementAmountInBaseCurrency: _amountInBaseCurrency,
            settlementAmountInSpotCurrency: _amountInSpotCurrency,
            exchangeRateAtSettlement: _currentExchangeRate,
            contractRate: _contractRate,
            timestamp: block.timestamp
        }));
    }

    function getIRS() external view returns (Types.IRS memory) {
        return irs;
    }

    function getTradeState() external view returns (Types.TradeState) {
        return tradeState;
    }

    function getMargin(address party) external view returns (Types.Margin memory) {
        return margin[party];
    }

    function getMarginRequirement(address _account) external view returns(Types.MarginRequirement memory) {
        return marginRequirements[_account];
    }

    function getPendingRequest(uint256 requestId) external view returns (address) {
        return pendingRequests[requestId];
    }

    function getTradeId() external view returns (string memory) {
        return tradeId;
    }

    function getInitialMargin() external view returns (uint256) {
        return initialMargin;
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

    function getFrictionlessFXSwapAddress() external view returns (address) {
        return frictionlessFXSwapAddress;
    }

    /**
    function getExchangePriceFeed() external view returns (address) {
        return address(exchangePriceFeed);
    }
    */

    function getLastUsedExchangeRate() external view returns (int256) {
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

    function getMarginCallAmount() external view returns (uint256) {
        return marginCallAmount;
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

    function getContractForwardAmount() public view returns (int256) {
        uint256 scale = _scaleTokens(irs.baseCurrency);
        uint256 notional = irs.notionalAmount * scale;
        uint256 rateDecimals = IRates(ratesContractAddress).decimals();
        uint256 rateScale = 10 ** rateDecimals;
        return irs.contractRate * int256(notional) / int256(rateScale);
    }

    function _scaleTokens(address _currency) private view returns (uint256) {
        uint8 decimal = IToken(_currency).decimals();
        return 10 ** decimal;
    }

    /**
    * @dev Returns the decimal scale for the settlement currency.
    * This is used to ensure that all amounts are correctly scaled
    * according to the token's decimal places.
    */
    function _scaleBaseCurrencyTokens() private view returns (uint256) {
        uint8 decimal = IToken(irs.baseCurrency).decimals();
        return 10 ** decimal;
    }
}