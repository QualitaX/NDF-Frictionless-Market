// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
* @notice This contract simulates the fluctuation of a Floating Rate benchmark
*/

/**
* @author Samuel Edoumou
* @dev This contrat hosts a list of EUR/USD rates (Close) for 5 days (from 2025-08-11 to 2025-08-15).
* The rates are expressed in 6 decimals (e.g., 1.1648 is represented as 1164800)
* The rates are sourced from `finance.yahoo.com`
*/
contract Rates {
    error invalidRateIndex(uint256 _index);

    uint256 public rateCount;
    uint8 private _ratedecimal = 7;
    int256[7] rates = [int256(117931), int256(118130), int256(118320), int256(118526), int256(118702), int256(118861), int256(119044)];

    function decimals() external view returns(uint8) {
        return _ratedecimal;
    }

    function getRate() external returns(int256) {
        uint256 index = rateCount;
        rateCount = index + 1;

        if(index >= rates.length) revert invalidRateIndex(index);

        return rates[index];
    }
}

// fixed rate = 35500000