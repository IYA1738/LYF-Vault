//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "contracts/release/Core/Vault/IVault.sol";
import "contracts/release/infrastructure/price-feeds/IChainlinkPriceFeedsRouter.sol";
import "contracts/release/infrastructure/utils/IMinimumERC20.sol";
import "contracts/release/Strategies/IStrategyBase.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract VaultValueCalculator{
    //合约中有两个NAV需要区分开
    //最终的NAV是策略给的NAV减去Protocol Fee后的
    //策略NAV只是策略自己的NAV

    address private _priceRouter;
    
    function getTotalValueInVault(address _vaultProxy, address baseToken) public view returns(uint256){
        address[] memory assets = IVault(_vaultProxy).getAssetsBalance();

        uint256 totalValue = 0;
        uint256 assetsCount = assets.length;
        for(uint256 i = 0; i< assetsCount;){
            address asset = assets[i];
            uint256 balance = IMinimumERC20(asset).balanceOf(_vaultProxy);
            uint8 decimals = IMinimumERC20(asset).decimals();
            uint256 convertRate = IChainlinkPriceFeedsRouter(_priceRouter).getPrice1e18(asset, baseToken);
            totalValue += Math.mulDiv(balance, convertRate, Math.pow10(decimals), Math.Rounding.Floor);
            unchecked {
                i++;
            }
        }
        return totalValue;
    }

    function getStrategiesNAV(address _vaultProxy, address baseToken) public view returns(uint256){
        address[] memory strategies = IVault(_vaultProxy).getAllRunningStrategies();
        uint256 strategiesCount = strategies.length;
        uint256 strategiesNAV = 0;
        for(uint i = 0; i< strategiesCount;){
            strategiesNAV += IStrategyBase(strategies[i]).strategyNAV();
            unchecked {
                i++;
            }
        }
        return strategiesNAV;
    }

    function getVaultNAV(address _vaultProxy, address baseToken) public view returns(uint256){
        return 0; // padding
    }
}