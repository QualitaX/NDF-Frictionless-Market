// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "./interfaces/IERC6123.sol";
import "./ERC6123Storage.sol";
import "./assets/ERC7586.sol";

contract NDF is IERC6123, ERC6123Storage, ERC7586 {
    event CollateralUpdated(string tradeID, address updater, uint256 collateralAmount);
    event LinkWithdrawn(string tradeID, address account, uint256 amount);
    event ContractSettled(string tradeID, address payer, address receiver, uint256 netSettlementAmount, uint256 fixedRatePayment, uint256 floatingRatePayment);
    event MarginAndFeesWithdrawn(string tradeID, address account, uint256 margin, uint256 fees);
    event SettlementForwderSet(string tradeID, address account, address forwarderAddress);
    event CollateralAdjustementForwaderSet(string tradeID, address account, address forwarderAddress);

    modifier onlyCounterparty() {
        require(
            msg.sender == irs.partyA || msg.sender == irs.partyB,
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

    constructor (
        string memory _tradeID,
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        uint256 _initialMarginBuffer,
        uint256 _initialTerminationFee,
        address _participantRegistryContractAddress,
        address _ratesContractAddress,
        address _identityRegistryContractAddress
    ) ERC7586(_irsTokenName, _irsTokenSymbol, _irs, _participantRegistryContractAddress, _ratesContractAddress, _identityRegistryContractAddress) {
        IParticipantRegistry(_participantRegistryContractAddress).checkUserVerification(_irs.partyA);
        IParticipantRegistry(_participantRegistryContractAddress).checkUserVerification(_irs.partyB);

        initialMarginBuffer = _initialMarginBuffer;
        initialTerminationFee = _initialTerminationFee;
        confirmationTime = 1 days;
        tradeID = _tradeID;
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
        if(inceptor == _withParty)
            revert cannotInceptWithYourself(msg.sender, _withParty);
        require(
            _withParty == irs.partyA || _withParty == irs.partyB,
            "Wrong 'withParty' address, MUST BE the counterparty"
        );
        require(_position == 1 || _position == -1, "invalid position");

        if(_position == 1) {
            irs.partyA = msg.sender;
            irs.partyB = _withParty;
        } else {
            irs.partyB = msg.sender;
            irs.partyA = _withParty;
        }

        tradeState = TradeState.Incepted;

        uint256 dataHash = uint256(keccak256(
            abi.encode(
                msg.sender,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));

        pendingRequests[dataHash] = msg.sender;
        tradeHash = Strings.toString(dataHash);
        inceptingTime = block.timestamp;

        uint8 decimal = IToken(irs.settlementCurrency).decimals();

        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer * 10**decimal,
            terminationFee: initialTerminationFee * 10**decimal
        });

        //The initial margin (collateral) and the termination fee must be deposited into the contract
        uint256 marginAndFee = (initialMarginBuffer + initialTerminationFee) * 10**decimal;
        uint256 upfrontPayment = uint256(_paymentAmount) * 10**decimal;

        require(upfrontPayment == marginAndFee, "Invalid payment amount");

        require(
            IToken(irs.settlementCurrency).transferFrom(msg.sender, treasuryContractAddress, marginAndFee),
            "Failed to transfer the initial margin + the termination fee"
        );

        emit TradeIncepted(
            msg.sender,
            _withParty,
            tradeHash,
            tradeID,
            _position,
            _paymentAmount,
            _initialSettlementData
        );

        return tradeHash;
    }

    
    function confirmTrade(
        address _withParty,
        string memory _tradeData,
        int256 _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted onlyWithinConfirmationTime {
        address inceptingParty = otherParty();

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                _withParty,
                msg.sender,
                _tradeData,
                -_position,
                -_paymentAmount,
                _initialSettlementData
            )
        ));

        if(pendingRequests[confirmationHash] != inceptingParty)
            revert inconsistentTradeDataOrWrongAddress(inceptingParty, confirmationHash);

        delete pendingRequests[confirmationHash];
        tradeState = TradeState.Confirmed;

        uint256 decimal = IToken(irs.settlementCurrency).decimals();

        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer * 10**decimal,
            terminationFee: initialTerminationFee * 10**decimal
        });

        //The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = (initialMarginBuffer + initialTerminationFee) * 10**decimal;
        //uint256 upfrontPayment = uint256(_paymentAmount) * 10**decimal;
        
        //require(upfrontPayment == marginAndFee, "Invalid payment amount");
        require(
            IToken(irs.settlementCurrency).transferFrom(msg.sender, treasuryContractAddress, marginAndFee),
            "Failed to transfer the initial margin + the termination fee"
        );

        emit TradeConfirmed(msg.sender, tradeID);
    }

    function cancelTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted onlyBeforeMaturity {
        address inceptingParty = msg.sender;

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                msg.sender,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));

        if(pendingRequests[confirmationHash] != inceptingParty)
            revert inconsistentTradeDataOrWrongAddress(inceptingParty, confirmationHash);

        delete pendingRequests[confirmationHash];
        tradeState = TradeState.Inactive;

        emit TradeCanceled(msg.sender, tradeID);
    }

    /**
    * @notice We don't implement the `initiateSettlement` function since this is done automatically
    */
    function initiateSettlement() external pure override {
        revert obseleteFunction();
    }
    
    /**
    * @notice In case of Chainlink ETH Staking Rate, the rateMultiplier = 3. And the result MUST be devided by 10^7
    *         We assume rates are input in basis point
    */
    function performSettlement(
        int256 _settlementAmount,
        string memory _settlementData
    ) public override {
        swap();

        tradeState = TradeState.Matured;
        emit SettlementEvaluated(msg.sender, _settlementAmount, _settlementData);
    }

    /**
    * @notice We don't implement the `afterTransfer` function since the transfer of the contract
    *         net present value is transferred in the `performSettlement function`.
    */
    function afterTransfer(bool /**success*/, string memory /*transactionData*/) external pure override {
        revert obseleteFunction();
    }

    /**-> NOT CLEAR: Why requesting trade termination after the trade has been settled ? */
    function requestTradeTermination(
        string memory _tradeHash,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external override onlyCounterparty onlyWhenSettled onlyBeforeMaturity {
        if(
            keccak256(abi.encodePacked(_tradeHash)) != keccak256(abi.encodePacked(tradeHash))
        ) revert invalidTrade(_tradeHash);

        uint256 terminationHash = uint256(keccak256(
            abi.encode(
                _tradeHash,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        pendingRequests[terminationHash] = msg.sender;

        emit TradeTerminationRequest(msg.sender, tradeID, _terminationPayment, _terminationTerms);
    }

    function confirmTradeTermination(
        string memory _tradeHash,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external onlyCounterparty onlyWhenSettled onlyBeforeMaturity {
        address pendingRequestParty = otherParty();

        uint256 confirmationhash = uint256(keccak256(
            abi.encode(
                _tradeHash,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        if(pendingRequests[confirmationhash] != pendingRequestParty)
            revert inconsistentTradeDataOrWrongAddress(pendingRequestParty, confirmationhash);

        delete pendingRequests[confirmationhash];

        address terminationPayer = otherParty();
        terminationReceiver = msg.sender;
        uint256 buffer = marginRequirements[terminationReceiver].marginBuffer + marginRequirements[terminationPayer].marginBuffer;
        uint256 fees = marginRequirements[terminationReceiver].terminationFee + marginRequirements[terminationPayer].terminationFee;
        terminationAmount = buffer + fees;

        _updateMargin(terminationPayer, terminationReceiver);

        terminateSwap();

        tradeState = TradeState.Terminated;

        emit TradeTerminationConfirmed(msg.sender, tradeID, int256(terminationAmount), _terminationTerms);
    }

    function cancelTradeTermination(
        string memory _tradeHash,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external onlyWhenSettled onlyBeforeMaturity {
        address pendingRequestParty = msg.sender;

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                _tradeHash,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        if(pendingRequests[confirmationHash] != pendingRequestParty)
            revert inconsistentTradeDataOrWrongAddress(pendingRequestParty, confirmationHash);

        delete pendingRequests[confirmationHash];

        emit TradeTerminationCanceled(msg.sender, tradeID, _terminationTerms);
    }

    /**
     * @notice Checks if collateral needs to be posted by either party. This function is called daily.
     *         This function is called by the automation provider like Chainlink..
    */
    function CheckMarginCall() external onlyWhenTradeConfirmed onlyBeforeMaturity {
        require(
            msg.sender == collateralAdjustementForwarderAddress,
            "Only the settlement forwarder can call this function"
        );

        uint256 notional = irs.notionalAmount;
        int256 fixedRate = irs.swapRate;
        int256 floatingRate = int256(IRates(ratesContractAddress).getRate()) + irs.spread;
        uint256 principalDecimal = IToken(irs.settlementCurrency).decimals();
        uint256 rateDecimal = IRates(ratesContractAddress).decimals();

        uint256 fixedPayment = notional * uint256(fixedRate) * 10**principalDecimal * 100 / (10**rateDecimal * 36525);
        uint256 floatingPayment = notional * uint256(floatingRate) * 10**principalDecimal * 100 / (10**rateDecimal * 36525); // spread = 0

        uint256 netCollateralAmount;
        if(fixedRate == floatingRate) {
            emit CollateralUpdated(tradeID, address(0), 0);
        } else if(fixedRate > floatingRate) {
            uint256 currentCollateralAmount = marginCalls[irs.partyA];
            netCollateralAmount = fixedPayment - floatingPayment;
            marginCalls[irs.partyA] = currentCollateralAmount + netCollateralAmount;

            emit CollateralUpdated(tradeID, irs.partyA, netCollateralAmount);
        } else {
            uint256 currentCollateralAmount = marginCalls[irs.partyB];
            netCollateralAmount = floatingPayment - fixedPayment;
            marginCalls[irs.partyB] = currentCollateralAmount + netCollateralAmount;

            emit CollateralUpdated(tradeID, irs.partyB, netCollateralAmount);
        }
    }

    /**
     * @notice Settles the SDC contract after it matures
     *         This function is called by the automation provider like Chainlink.
    */
    function settle() external onlyAfterMaturity {
        require(
            msg.sender == settlementForwarderAddress,
            "Only the settlement forwarder can call this function"
        );

        fixedRatePayment = marginRequirements[irs.partyA].marginBuffer - initialMarginBuffer;
        floatingRatePayment = marginRequirements[irs.partyB].marginBuffer - initialMarginBuffer;

        uint8 decimal = decimals();
        if(fixedRatePayment == floatingRatePayment) {
            uint256 irsTokenUnit = 10**decimal;
            burn(irs.partyA, irsTokenUnit);
            burn(irs.partyB, irsTokenUnit);

            marginCalls[irs.partyA] = 0;
            marginCalls[irs.partyB] = 0;

            irsReceipts.push(
                Types.IRSReceipt({
                    from: address(0),
                    to: address(0),
                    netAmount: 0,
                    timestamp: block.timestamp,
                    fixedRatePayment: fixedRatePayment,
                    floatingRatePayment: floatingRatePayment
                })
            );
        } else if(fixedRatePayment > floatingRatePayment) {
            settlementAmount = fixedRatePayment - floatingRatePayment;
            payerParty = irs.partyA;
            receiverParty = irs.partyB;

            marginRequirements[payerParty].marginBuffer = marginRequirements[payerParty].marginBuffer - settlementAmount;
            marginCalls[payerParty] = 0;

            uint256 irsTokenUnit = 10**decimal;
            burn(irs.partyA, irsTokenUnit);
            burn(irs.partyB, irsTokenUnit);
            _updateIRSReceipt(settlementAmount);
            performSettlement(int256(settlementAmount), tradeID);

            emit ContractSettled(tradeID, payerParty, receiverParty, settlementAmount, fixedRatePayment, floatingRatePayment);
        } else {
            settlementAmount = floatingRatePayment - fixedRatePayment;
            payerParty = irs.partyB;
            receiverParty = irs.partyA;

            marginRequirements[payerParty].marginBuffer = marginRequirements[payerParty].marginBuffer - settlementAmount;
            marginCalls[payerParty] = 0;

            uint256 irsTokenUnit = 10**decimal;
            burn(irs.partyA, irsTokenUnit);
            burn(irs.partyB, irsTokenUnit);
            _updateIRSReceipt(settlementAmount);
            performSettlement(int256(settlementAmount), tradeID);

            emit ContractSettled(tradeID, payerParty, receiverParty, settlementAmount, fixedRatePayment, floatingRatePayment);
        }
    }

    /**
    * @notice Trabsfers the collateral to the smart contract after receiving a margin call
    */
    function postCollateral() external onlyCounterparty onlyWhenTradeConfirmed onlyBeforeMaturity {
        uint256 currentMargin = marginCalls[msg.sender];
        uint256 buffer = marginRequirements[msg.sender].marginBuffer;

        marginCalls[msg.sender] = 0;
        marginRequirements[msg.sender].marginBuffer = buffer + currentMargin;
        
        require(
            IToken(irs.settlementCurrency).transferFrom(msg.sender, address(this), currentMargin),
            "Failed to transfer the collateral"
        );

        emit CollateralUpdated(tradeID, msg.sender, marginRequirements[msg.sender].marginBuffer);
    }

    function setCollateralAdjustementForwarderAddress(address _address) external onlyCounterparty {
        collateralAdjustementForwarderAddress = _address;

        emit CollateralAdjustementForwaderSet(tradeID, msg.sender, _address);
    }

    function setSettlementForwarderAddress(address _address) external onlyCounterparty {
        settlementForwarderAddress = _address;

        emit SettlementForwderSet(tradeID, msg.sender, _address);
    }

    /**
    * @notice Withdraws the initial margin and the termination fee after the trade has matured
    *         The margin buffer and the initial fees are reset to 0 after the withdrawal
    */
    function withdrawInitialMarginAndTerminationFees() external onlyCounterparty onlyAfterMaturity {
        uint256 amount = marginRequirements[msg.sender].marginBuffer + marginRequirements[msg.sender].terminationFee;
        
        require(
            IToken(irs.settlementCurrency).transfer(msg.sender, amount),
            "Failed to transfer the initial margin and the termination fee"
        );

        emit MarginAndFeesWithdrawn(tradeID, msg.sender, marginRequirements[msg.sender].marginBuffer, marginRequirements[msg.sender].terminationFee);

        marginRequirements[msg.sender].marginBuffer = 0;
        marginRequirements[msg.sender].terminationFee = 0;
    }

    /**
     * @notice Allow withdraw of Link tokens from the contract
     * !!!!!   SECURE THIS FUNCTION FROM BEING CALLED BY NOT ALLOWED USERS !!!!!
     * !!!!!   WITHDRAWAL SHOULD ALSO BE POSSIBLE IN CASE OF TERMINATION   !!!!!
     */
    function withdrawLink() public onlyAfterMaturity onlyCounterparty {
        LinkTokenInterface link = LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );

        emit LinkWithdrawn(tradeID, msg.sender, link.balanceOf(address(this)));
    }

    function getContractLINKBalance() external view returns(uint256) {
        LinkTokenInterface link = LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        return link.balanceOf(address(this));
    }

    /**---------------------- Internal Private and other view functions ----------------------*/
    function _updateIRSReceipt(uint256 _settlementAmount) private {
        irsReceipts.push(
            Types.IRSReceipt({
                from: payerParty,
                to: receiverParty,
                netAmount: _settlementAmount,
                timestamp: block.timestamp,
                fixedRatePayment: fixedRatePayment,
                floatingRatePayment: floatingRatePayment
            })
        );
    }

    function _updateMargin(address _payer, address _receiver) private {
        marginRequirements[_payer].marginBuffer = 0;
        marginRequirements[_payer].terminationFee = 0;
        marginRequirements[_receiver].marginBuffer = 0;
        marginRequirements[_receiver].terminationFee = 0;
    }

    function getTradeState() external view returns(TradeState) {
        return tradeState;
    }

    function getTradeID() external view returns(string memory) {
        return tradeID;
    }

    function getTradeHash() external view returns(string memory) {
        return tradeHash;
    }

    function getInceptingTime() external view returns(uint256) {
        return inceptingTime;
    }

    function getConfirmationTime() external view returns(uint256) {
        return confirmationTime;
    }

    function getInitialMargin() external view returns(uint256) {
        return initialMarginBuffer;
    }

    function getInitialTerminationFee() external view returns(uint256) {
        return initialTerminationFee;
    }

    function getMarginCall(address _account) external view returns(uint256) {
        return marginCalls[_account];
    }

    function getMarginRequirement(address _account) external view returns(Types.MarginRequirement memory) {
        return marginRequirements[_account];
    }

    function otherParty() internal view returns(address) {
        return msg.sender == irs.partyA ? irs.partyB : irs.partyA;
    }

    function otherParty(address _account) internal view returns(address) {
        return _account == irs.partyA ? irs.partyB : irs.partyA;
    }

    function getIRSReceipts() external view returns(Types.IRSReceipt[] memory) {
        return irsReceipts;
    }


    /**======== TO BE REMOVED BEFORE PRODUCTION */
    /**
    * @notice Withdraw all tokens stored in the contract
    */
    function withdrawTokens() external onlyCounterparty {
        uint256 balance =  IToken(irs.settlementCurrency).balanceOf(address(this));
        require(balance > 0, "Insufficient balance");

        IToken(irs.settlementCurrency).transfer(msg.sender, balance);
    }
}