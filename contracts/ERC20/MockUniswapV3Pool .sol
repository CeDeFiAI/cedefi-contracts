// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "../interfaces/IUniswapV3Pool.sol";
contract MockUniswapV3Pool is IUniswapV3Pool {
    address private _token0;
    address private _token1;

    constructor(address firstToken, address secondToken) {
        _token0 = firstToken;
        _token1 = secondToken;
        
    }

    function slot0() external pure override returns (
        uint160,
        int24,
        uint16,
        uint16,
        uint16,
        uint8,
        bool
    ) {
        return (0, 0, 0, 0, 0, 0, false);
    }

    function token0() external view override returns (address) {
        return _token0;
    }

    function token1() external view override returns (address) {
        return _token1;
    }
}
