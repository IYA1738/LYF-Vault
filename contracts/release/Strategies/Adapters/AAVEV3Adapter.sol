//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 <0.9.0;

import "contracts/external-interfaces/IAAVE-V3.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/release/Strategies/Adapters/interfaces/SingleAssetInterfaces/AdapterInterface.sol";

contract AAVEV3Adapter is AdapterInterface{
    
    using SafeERC20 for IERC20;

    address public immutable aaveV3;

    constructor(address _aaveV3){
        aaveV3 = _aaveV3;
    }

    //要加权限 可调用者是白名单策略
    function entry(address asset, uint256 amount, bytes calldata data) external override{
        (address onBehalfOf, uint16 referralCode) = abi.decode(data,(address, uint16));
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IPool(aaveV3).supply(asset, amount, onBehalfOf, referralCode);
    }

    function exit(bytes calldata data) external override{
        (address asset, uint256 amount, address to) = abi.decode(data,(address, uint256, address));
        IPool(aaveV3).withdraw(asset, amount, to);
    }

    function externalProtocol() external view override returns(address){
        return aaveV3;
    }

}