//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 < 0.9.0;

abstract contract OnlyDelegate{
    address private immutable _origin_onlyDelegate = address(this);

    function _checkOnlyDelegate() private view{
        require(address(this) == _origin_onlyDelegate, "Only Delegate");
    }

    modifier onlyDelegateCall{
        _checkOnlyDelegate();
        _;
    }
}