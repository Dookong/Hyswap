// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";

contract PairTest is Test{
    HySwapPair pair;
    ERC20Mintable token0;
    ERC20Mintable token1;

    function setUp() public {
        token0 = new ERC20Mintable("A", "TKA");
        token1 = new ERC20Mintable("B", "TKB");
        pair = new HySwapPair(address(token0), address(token1));

        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));
    }

    function assertReserves(uint112 expectedReserve0, uint112 expectedReserve1) internal {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve1");
    }

    function testMintBootstrap() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(0 ether, 0 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }
}