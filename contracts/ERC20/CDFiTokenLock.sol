// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../utils/TokenTimelock.sol";


contract CDFiTokenLock is TokenTimelock {

    constructor(address _token, address _beneficiary, uint256 _timestamp) TokenTimelock(IERC20(_token), _beneficiary, _timestamp){}
}
