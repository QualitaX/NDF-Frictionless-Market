// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./TREX/interfaces/IToken.sol";
import "../Types.sol";

/**
* @notice This token contract allows tokenize Interest Rate Swap cashflows.
*         Approval and Transfer of tokens are allowed only before the IRS contract reaches maturity.
*         This feature prevents tokens to be traded after the contract has matured.
*         When tokens are transferred to an account, the ownership (partyA or partyB) is also transferred.
*         The contract doesn't support partial transfer of tokens. All the balance must be transferred for the transaction to be successful.
*/
abstract contract SwapToken is IToken {
    Types.IRS internal irs;

    modifier onlyBeforeMaturity() {
        require(
            block.timestamp <= irs.maturityDate,
            "IRS contract has reached the Maturity Date"
        );
        _;
    }

    modifier onlyWhenTradeInactive() {
        require(
            tradeState == TradeState.Inactive,
            "Trade state is not 'Inactive'."
        ); 
        _;
    }

    modifier onlyWhenTradeIncepted() {
        require(
            tradeState == TradeState.Incepted,
            "Trade state is not 'Incepted'."
        );
        _;
    }

    modifier onlyWhenTradeConfirmed() {
        require(
            tradeState == TradeState.Confirmed,
            "Trade state is not 'Confirmed'." 
        );
        _;
    }

    modifier onlyWhenSettled() {
        require(
            tradeState == TradeState.Settled,
            "Trade state is not 'Settled'."
        );
        _;
    }

    modifier onlyWhenValuation() {
        require(
            tradeState == TradeState.Valuation,
            "Trade state is not 'Valuation'."
        );
        _;
    }

    modifier onlyWhenInTermination () {
        require(
            tradeState == TradeState.InTermination,
            "Trade state is not 'InTermination'."
        );
        _;
    }

    modifier onlyWhenInTransfer() {
        require(
            tradeState == TradeState.InTransfer,
            "Trade state is not 'InTransfer'."
        );
        _;
    }

    modifier onlyWhenMatured() {
        require(
            tradeState == TradeState.Matured,
            "Trade state is not 'Matured'."
        );
        _;
    }

    modifier onlyWhenConfirmedOrSettled() {
        if(tradeState != TradeState.Confirmed) {
            if(tradeState != TradeState.Settled) {
                revert stateMustBeConfirmedOrSettled();
            }
        }
        _;
    }

    modifier onlyWithinConfirmationTime() {
        require(
            block.timestamp - inceptingTime <= confirmationTime,
            "Confimartion time is over"
        );
        _;
    }

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 internal _totalSupply;
    uint256 internal _maxSupply;
    uint256 private _burnedSupply;

    string private _name;
    string private _symbol;

    error supplyExceededMaxSupply(uint256 totalSupply_, uint256 maxSupply_);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function maxSupply() public view returns(uint256) {
        return _maxSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "SwapToken: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual onlyBeforeMaturity {
        require(from != address(0), "SwapToken: transfer from the zero address");
        require(to != address(0), "SwapToken: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance == amount, "SwapToken: you must transfer all your balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        if(from == irs.partyA) {
            irs.partyA = to;
        } else if(from == irs.partyB) {
            irs.partyB = to;
        } else {
            revert("invalid from address");
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function mint(address account, uint256 amount) public virtual override {
        require(account != address(0), "SwapToken: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        if (_totalSupply + _burnedSupply > _maxSupply) revert supplyExceededMaxSupply(_totalSupply, _maxSupply);

        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) public virtual {
        require(account != address(0), "SwapToken: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "SwapToken: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
            _burnedSupply += amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual onlyBeforeMaturity {
        require(owner != address(0), "SwapToken: approve from the zero address");
        require(spender != address(0), "SwapToken: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "SwapToken: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
    function setName(string calldata name_) external virtual {}
    function setSymbol(string calldata symbol_) external virtual {}
    function setOnchainID(address _onchainID) external virtual {}
    function pause() external virtual {}
    function unpause() external virtual {}
    function setAddressFrozen(address _userAddress, bool _freeze) external virtual {}
    function freezePartialTokens(address _userAddress, uint256 _amount) external virtual {}
    function unfreezePartialTokens(address _userAddress, uint256 _amount) external virtual {}
    function setIdentityRegistry(address _identityRegistry) external virtual {}
    function setCompliance(address _compliance) external virtual {}
    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external virtual returns (bool) {}
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external virtual returns (bool) {}
    function batchTransfer(address[] calldata _toList, uint256[] calldata _amounts) external virtual {}
    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external virtual {}
    function batchMint(address[] calldata _toList, uint256[] calldata _amounts) external virtual {}
    function batchBurn(address[] calldata _userAddresses, uint256[] calldata _amounts) external virtual {}
    function batchSetAddressFrozen(address[] calldata _userAddresses, bool[] calldata _freeze) external virtual {}
    function batchFreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external virtual {}
    function batchUnfreezePartialTokens(address[] calldata _userAddresses, uint256[] calldata _amounts) external virtual {}
    function onchainID() external view virtual returns (address) {}
    function version() external view virtual returns (string memory) {}
    function identityRegistry() external view virtual returns (IIdentityRegistry) {}
    function compliance() external view virtual returns (IModularCompliance) {}
    function paused() external view virtual returns (bool) {}
    function isFrozen(address _userAddress) external view virtual  returns (bool) {}
    function getFrozenTokens(address _userAddress) external view virtual  returns (uint256) {}
}