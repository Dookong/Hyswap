pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/HySwapRouter.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/contracts/Factory.sol";


contract RemoveLiquidityTest is Test {
    ERC20Mintable public tokenA;
    ERC20Mintable public tokenB;

    HySwapRouter router;
    Factory factory;

    function setUp() public {
        tokenA = new ERC20Mintable("A", "TKA");
        tokenB = new ERC20Mintable("B", "TKB");

        (tokenA, tokenB) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);

        factory = new Factory(address(this));
        router = new HySwapRouter(address(factory));

        tokenA.mint(20 ether, address(this));
        tokenB.mint(20 ether, address(this));
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function testRemoveLiquidity() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 1 ether, 1 ether, address(this));

        HySwapPair pair = HySwapPair(factory.getPair(address(tokenA), address(tokenB)));
        uint256 _liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), _liquidity);

        assertEq(tokenA.balanceOf(address(this)), 19 ether);
        assertEq(tokenB.balanceOf(address(this)), 19 ether);

        assertEq(tokenA.balanceOf(address(pair)), 1 ether);
        assertEq(tokenB.balanceOf(address(pair)), 1 ether);

        router.removeLiquidity(address(tokenA), address(tokenB), _liquidity, 1 ether - 1000, 1 ether - 1000, address(this));

        (uint112 reserveA, uint112 reserveB,) = pair.getReserves();

        assertEq(reserveA, 1000);
        assertEq(reserveB, 1000);

        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), 1000);   
    }

    function testRemoveLiquidityPartially() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 1 ether, 1 ether, address(this));

        HySwapPair pair = HySwapPair(factory.getPair(address(tokenA), address(tokenB)));
        uint256 _liquidity = pair.balanceOf(address(this));

        _liquidity =( _liquidity * 3 )/ 10; //( 1ether - 1000 )* 0.3

        pair.approve(address(router), _liquidity);

        router.removeLiquidity(address(tokenA), address(tokenB), _liquidity, 0.3 ether - 300,0.3 ether - 300, address(this));

        (uint112 reserveA, uint112 reserveB,) = pair.getReserves();

        assertEq(reserveA, 0.7 ether + 300);
        assertEq(reserveB, 0.7 ether + 300);

        assertEq(pair.balanceOf(address(this)), 0.7 ether - 700);
        assertEq(pair.totalSupply(), 0.7 ether + 300);
        assertEq(tokenA.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
        assertEq(tokenB.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
    }        
    // todo


}


