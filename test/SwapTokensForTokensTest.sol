pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/HySwapRouter.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/contracts/Factory.sol";


contract SwapTokensForTokensTest is Test {
    ERC20Mintable public tokenA;
    ERC20Mintable public tokenB;
    ERC20Mintable public tokenC;

    HySwapRouter router;
    Factory factory;

    function setUp() public {
        tokenA = new ERC20Mintable("A", "TKA");
        tokenB = new ERC20Mintable("B", "TKB");
        tokenC = new ERC20Mintable("C", "TKC");

        (tokenA, tokenB) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        (tokenA, tokenC) = address(tokenA) < address(tokenC) ? (tokenA, tokenC) : (tokenC, tokenA);
        (tokenB, tokenC) = address(tokenB) < address(tokenC) ? (tokenB, tokenC) : (tokenC, tokenB);

        factory = new Factory(address(this));
        router = new HySwapRouter(address(factory));

        tokenA.mint(20 ether, address(this));
        tokenB.mint(20 ether, address(this));
        tokenC.mint(20 ether, address(this));
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function testSwapExactTokensForTokens() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);
        tokenC.approve(address(router), 1 ether);

        router.addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 1 ether, 1 ether, address(this));
        router.addLiquidity(address(tokenB), address(tokenC), 1 ether, 1 ether, 1 ether, 1 ether, address(this));
        
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        tokenA.approve(address(router), 0.3 ether);
        router.swapExactTokensForTokens(0.3 ether, 0.1 ether, path, address(this));

        assertEq(tokenA.balanceOf(address(this)), 18.7 ether);
        assertEq(tokenB.balanceOf(address(this)), 18 ether);
        assertEq(tokenC.balanceOf(address(this)), 20 ether - 1 ether + 0.186691414219734305 ether );
    }

    function testSwapTokensForExactTokens() public {
        tokenA.approve(address(router), 1 ether);
        tokenB.approve(address(router), 2 ether);
        tokenC.approve(address(router), 1 ether);

        router.addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 1 ether, 1 ether, address(this));
        router.addLiquidity(address(tokenB), address(tokenC), 1 ether, 1 ether, 1 ether, 1 ether, address(this));
        
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);

        tokenA.approve(address(router), 0.3 ether);
        router.swapTokensForExactTokens(0.186691414219734305 ether, 0.3 ether, path, address(this));

        assertEq(tokenA.balanceOf(address(this)), 18.7 ether);
        assertEq(tokenB.balanceOf(address(this)), 18 ether);
        assertEq(tokenC.balanceOf(address(this)), 20 ether - 1 ether + 0.186691414219734305 ether );

    }
}


