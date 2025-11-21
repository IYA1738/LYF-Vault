// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IChainlinkPriceFeedsRouter {
    event SetDataFeed(address token0, address token1, address dataFeed);

    function owner() external view returns (address);

    function getPrice1e18(address token0, address token1)
        external
        view
        returns (uint256);

    function setDataFeed(address token0, address token1, address dataFeed)
        external;

    function dataFeeds(address token0, address token1)
        external
        view
        returns (AggregatorV3Interface);
}