// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
* @notice This contract simulates the fluctuation of a Floating Rate benchmark
*/

contract Rates {
    uint256 public rateCount;
    uint8 private _ratedecimal = 9;
    uint256[10] rates = [35400000, 35600000, 35800000, 35500000, 35400000, 35600000, 35700000, 35400000, 35300000, 35600000];

    function decimals() external view returns(uint8) {
        return _ratedecimal;
    }

    function getRate() external returns(uint256) {
        uint256 index = rateCount;
        rateCount = index + 1;

        require(index < 10, "invalid rate index");

        return rates[index];
    }
}