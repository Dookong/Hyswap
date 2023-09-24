pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/HySwapRouter.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/contracts/Factory.sol";


contract AddLiquidityTest is Test {
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


    function testAddLiquidity() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        router.addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 1 ether, 1 ether, address(this));

        HySwapPair pair = HySwapPair(factory.getPair(address(tokenA), address(tokenB)));
        assertEq(pair.balanceOf(address(this)), 999999999999999000); // minimum liquidity 1000

        assertEq(tokenA.balanceOf(address(this)), 19 ether);
        assertEq(tokenB.balanceOf(address(this)), 19 ether);

        assertEq(tokenA.balanceOf(address(pair)), 1 ether);
        assertEq(tokenB.balanceOf(address(pair)), 1 ether);
    }

    function testAddLiquidityNoPair() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
        .addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 1, 1, address(this));

        assertEq(amountA, 1 ether);
        assertEq(amountB, 1 ether);
        assertEq(liquidity, 1 ether - 1000);

        HySwapPair pair = HySwapPair(factory.getPair(address(tokenA), address(tokenB)));

        assertEq(tokenA.balanceOf(address(pair)), 1 ether);
        assertEq(tokenB.balanceOf(address(pair)), 1 ether);

        assertEq(tokenA.balanceOf(address(this)), 19 ether);
        assertEq(tokenB.balanceOf(address(this)), 19 ether);

        assertEq(pair.token0(), address(tokenA));
        assertEq(pair.token1(), address(tokenB));

        assertEq(pair.totalSupply(), 1 ether);
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
    }

    function testAddLiquidityCheckOptimal() public {
        HySwapPair pair = HySwapPair(factory.createPair(address(tokenA), address(tokenB)));

        assertEq(pair.token0(), address(tokenA));
        assertEq(pair.token1(), address(tokenB));

        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 2 ether);
        uint256 _liquidity = pair.mint(address(this));

        assertEq(_liquidity, 1414213562373094048);

        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
        .addLiquidity(address(tokenA), address(tokenB), 1 ether, 2 ether, 1 ether, 1.9 ether, address(this));

        assertEq(amountA, 1 ether);
        assertEq(amountB, 2 ether);
        assertEq(liquidity, 1414213562373095048);
        assertEq(_liquidity, liquidity - 1000);
    }

    function testAddLiquidityAmountBOptimalIsTooLow() public {
        HySwapPair pair = HySwapPair(factory.createPair(address(tokenA), address(tokenB)));

        assertEq(pair.token0(), address(tokenA));
        assertEq(pair.token1(), address(tokenB));

        tokenA.transfer(address(pair), 5 ether);
        tokenB.transfer(address(pair), 10 ether);
        uint256 _liquidity = pair.mint(address(this));


        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);

        vm.expectRevert(encodeError("InsufficientBAmount()")); 
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
        .addLiquidity(address(tokenA), address(tokenB), 1 ether, 2 ether, 1 ether, 2 ether, address(this));
    }

    function testAddLiquidityAmountBOptimalTooHighAmountATooLow() public {
        HySwapPair pair = HySwapPair(factory.createPair(address(tokenA), address(tokenB)));

        assertEq(pair.token0(), address(tokenA));
        assertEq(pair.token1(), address(tokenB));

        tokenA.transfer(address(pair), 10 ether);
        tokenB.transfer(address(pair), 5 ether);
        uint256 _liquidity = pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        vm.expectRevert(encodeError("InsufficientAAmount()"));
        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
        .addLiquidity(address(tokenA), address(tokenB), 2 ether, 0.9 ether, 2 ether, 1 ether, address(this));
    }

    function testAddLiquidityAmountBOptimalIsTooHighAmountAOk() public {
        HySwapPair pair = HySwapPair(factory.createPair(address(tokenA), address(tokenB)));

        assertEq(pair.token0(), address(tokenA));
        assertEq(pair.token1(), address(tokenB));

        tokenA.transfer(address(pair), 10 ether);
        tokenB.transfer(address(pair), 5 ether);
        uint256 _liquidity = pair.mint(address(this));

        tokenA.approve(address(router), 2 ether);
        tokenB.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
        .addLiquidity(address(tokenA), address(tokenB), 2 ether, 0.9 ether, 1.7 ether, 1 ether, address(this));

        assertEq(amountA, 1.8 ether);
        assertEq(amountB, 0.9 ether);
        assertEq(liquidity, 1272792206135785543);
    }
}