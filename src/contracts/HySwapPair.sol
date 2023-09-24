// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Math.sol";

// Errors
error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();

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

        uint balance0 = IERC20(token0).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token0의 개수
        uint balance1 = IERC20(token1).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token1의 개수
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
        _update(balance0, balance1);
    }

    function getReserves() public view returns (uint112, uint112, uint32){
        return (reserve0, reserve1, 0);
    }

    function _update(uint balance0, uint balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function burn() public {
        uint balance0 = IERC20(token0).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token0의 개수
        uint balance1 = IERC20(token1).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token1의 개수
        uint liquidity = balanceOf[msg.sender]; // 호출자가 보유한 

        uint amount0 = (liquidity * balance0) / totalSupply; //호출자가 가져갈 토큰의 양 = 
        uint amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned(); // 예외 처리

        _burn(msg.sender, liquidity);
    }
}