//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

interface IExternalPositionsManager{
    struct ExternalPosition{
        address strategy;
        address adapter;
        address target;
        address asset;
        uint256 amount;
    }

    function addExternalPosition(ExternalPosition memory _externalPosition) external;

    function removeExternalPosition(bytes32 key) external;
}