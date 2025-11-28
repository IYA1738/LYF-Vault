//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

//逻辑未完整，后续要补全 
contract ExternalPositionsManager is IExternalPositionsManager{

    uint256 public positionId;
    mapping(bytes32 => ExternalPosition[]) public externalPositions; //keccak256(strategy, external protocol) => ExternalPositions[]
    mapping(uint256 => uint256) public IdToIndex;

    event AddExternalPosition(address strategy, address target, address asset, uint256 amount, uint96 index);

    struct ExternalPosition{
        address strategy;
        uint96 index;

        address target; //External protocol
        address asset;
        uint256 amount;
    }

    function addExternalPosition(address strategy, address target, address asset, uint256 amount) external override{
        bytes32 bucketKey = keccak256(abi.encode(strategy, target));
        ExternalPosition[] storage positions = externalPositions[bucketKey];
        positions.push(ExternalPosition({
            strategy: strategy,
            index: positions.length,
            target: target,
            asset: asset,
            amount: amount
        }));
        IdToIndex[positionId++] = positions.length; //index+1 avoid conflicting with 0 of mapping 避免和mapping的0冲突
        emit AddExternalPosition(strategy, target, asset, amount, positions.length - 1);
    }

    function removeExternalPosition(bytes32 key) external override{

    }
}