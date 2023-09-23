// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Math.sol";

error InsufficientLiquidityMinted();

contract HySwapPair is ERC20{
    uint constant MIN_LIQUIDITY = 1000;

    uint112 private reserve0;
    uint112 private reserve1;

    address public token0;
    address public token1;

    constructor(address token0_, address token1_) ERC20("HySwapPair", "HY_V2", 18) {
        token0 = token0_;
        token1 = token1_;
    }

    function mint() public {
        Math math_module = new Math();

        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - reserve0;
        uint amount1 = balance1 - reserve1;

        uint liquidity;

        if (totalSupply == 0) {
            liquidity = math_module.sqrt(amount0 * amount1) - MIN_LIQUIDITY;
            _mint(address(0), MIN_LIQUIDITY);
        }
        else {
            liquidity = math_module.min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();
        _mint(msg.sender, liquidity);
    }

    function getReserves() public view returns (uint112, uint112, uint32){
        return (reserve0, reserve1, 0);
    }
}