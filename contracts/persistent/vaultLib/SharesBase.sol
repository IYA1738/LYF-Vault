//SPDX-License-Identifier:MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract SharesBase is ERC20Upgradeable{
    function __init_SharesBase(string memory name, string memory symbol) internal onlyInitializing{
        __ERC20_init(name, symbol);
    }
}