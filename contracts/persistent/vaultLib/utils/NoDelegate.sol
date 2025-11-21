//SPDX-License-Identifier:MIT
pragma solidity >=0.8.0 < 0.9.0;

abstract contract NoDelegate{
    address private immutable _origin_noDelegate = address(this);

    function _checkNoDelegate() private view{
        require(address(this) == _origin_noDelegate, "No Delegate");
    }

    modifier noDelegateCall{
        _checkNoDelegate();
        _;
    }
}