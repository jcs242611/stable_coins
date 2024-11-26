// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract MockAggregator {
    int256 private price;
    uint8 private decimalsCount;

    constructor(int256 _initialPrice, uint8 _decimals) {
        price = _initialPrice;
        decimalsCount = _decimals;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, price, 0, block.timestamp, 0);
    }

    function decimals() external view returns (uint8) {
        return decimalsCount;
    }

    function setPrice(int256 _newPrice) external {
        price = _newPrice;
    }
}
