// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/contracts/Factory.sol";

contract FactoryTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    ERC20Mintable token2;
    Factory factory;

    function setUp() public {
        factory = new Factory(address(this));

        token0 = new ERC20Mintable("A", "TKA");
        token1 = new ERC20Mintable("B", "TKB");
        token2 = new ERC20Mintable("C", "TKC");
    }

    function testCreatePair() public {
        factory.createPair(address(token0), address(token1));
        factory.createPair(address(token0), address(token2));
        factory.createPair(address(token1), address(token2));

        assertEq(factory.allPairsLength(), 3);
    }
}