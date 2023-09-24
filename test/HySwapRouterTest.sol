pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/HySwapRouter.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/contracts/Factory.sol";


contract HySwapRouterTest is Test {
    ERC20Mintable public token0;
    ERC20Mintable public token1;

    HySwapRouter router;
    Factory factory;

    function setUp() public {
        token0 = new ERC20Mintable("A", "TKA");
        token1 = new ERC20Mintable("B", "TKB");

        factory = new Factory(address(this));
        router = new HySwapRouter(address(factory));

        token0.mint(20 ether, address(this));
        token1.mint(20 ether, address(this));
    }

    function testAddLiquidity() public {
        token0.approve(address(router), 10 ether);
        token1.approve(address(router), 10 ether);

        router.addLiquidity(address(token0), address(token1), 10 ether, 10 ether, 0, 0, address(this));

        HySwapPair pair = HySwapPair(factory.getPair(address(token0), address(token1)));
        assertEq(pair.balanceOf(address(this)), 9999999999999999000); // minimum liquidity 1000

        assertEq(token0.balanceOf(address(this)), 10 ether);
        assertEq(token1.balanceOf(address(this)), 10 ether);

        assertEq(token0.balanceOf(address(pair)), 10 ether);
        assertEq(token1.balanceOf(address(pair)), 10 ether);
    }
}