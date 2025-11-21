//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ChainlinkPRiceFeedsRouter is Ownable{

    event SetDataFeed(address token0, address token1, address _dataFeed);

    address private _comptroller;
    mapping(address => mapping(address => AggregatorV3Interface)) public dataFeeds;

    constructor(address initOwner) Ownable(initOwner){

    }

    function getPrice1e18(address token0, address token1)public view returns(uint256){
        require(msg.sender == _comptroller, "Only comptroller");
        
        AggregatorV3Interface dataFeed = dataFeeds[token0][token1];
         (
            ,
            int256 answer,
            ,
            uint256 updatedAt,
            
        ) = dataFeed.latestRoundData();

        require(answer > 0, "invalid");
        require(updatedAt > block.timestamp - 5 seconds, "stale");

        uint8 decimals = dataFeed.decimals();
        return uint256(answer) * (10 ** (18 - decimals)); 
    }

    function setDataFeed(address token0, address token1, address _dataFeed) external onlyOwner{
        dataFeeds[token0][token1] = AggregatorV3Interface(_dataFeed);
        emit SetDataFeed(token0, token1, _dataFeed);
    }
    
}