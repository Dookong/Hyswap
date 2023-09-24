// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";

contract PairOracleTest is Test{
    HySwapPair pair;
    ERC20Mintable token0;
    ERC20Mintable token1;

    // 기본 설정
    function setUp() public {
        token0 = new ERC20Mintable("A", "TKA");
        token1 = new ERC20Mintable("B", "TKB");
        pair = new HySwapPair(address(token0), address(token1));

        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));
    }

    // 풀에 예치된 토큰 개수 확인
    function assertReserves(uint112 expectedReserve0, uint112 expectedReserve1) internal {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve1");
    }

    function assertCumulativePrices(uint256 expectedPrice0, uint256 expectedPrice1) public {
        assertEq(pair.price0CumulativeLast(), expectedPrice0,"unexpected cumulative price0");
        assertEq(pair.price1CumulativeLast(), expectedPrice1,"unexpected cumulative price1");
    }
}