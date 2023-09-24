// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
// import "../src/interfaces/Vm.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/libraries/UQ112x112.sol";
import "../src/contracts/Factory.sol";

contract PairOracleTest is Test{
    HySwapPair pair;
    ERC20Mintable token0;
    ERC20Mintable token1;
    Factory factory;

    // 기본 설정
    function setUp() public {
        token0 = new ERC20Mintable("A", "TKA");
        token1 = new ERC20Mintable("B", "TKB");
        factory = new Factory(address(this));

        pair =  HySwapPair(factory.createPair(address(token0), address(token1)));

        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));
    }

    // 최신 타임스탬프 보장
    function assertBlockTimestampLast(uint32 expected) internal {
        (, , uint32 blockTimestampLast) = pair.getReserves();
        assertEq(blockTimestampLast, expected, "unexpected blockTimestampLast");
    }

    // 누적가격 보장
    function assertCumulativePrices(uint expectedPrice0, uint expectedPrice1) internal {
        assertEq(pair.price0CumulativeLast(),expectedPrice0,"unexpected cumulative price 0");
        assertEq(pair.price1CumulativeLast(),expectedPrice1,"unexpected cumulative price 0");
    }

    // 현재가 계산
    function calculateCurrentPrice() internal view returns (uint256 price0, uint256 price1) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        // UQ112x112.Q112 = 2**112
        // 가격 = 예치 비율
        price0 = reserve0 > 0 ? (reserve1 * uint256(UQ112x112.Q112)) / reserve0 : 0;
        price1 = reserve1 > 0 ? (reserve0 * uint256(UQ112x112.Q112)) / reserve1 : 0;
    }

    function testPrice() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);
        pair.mint(address(this)); //LP토큰 +1

        vm.warp(0);
        pair.sync();
        assertNotEq(pair.price0CumulativeLast(), 0, "is zero");
        vm.warp(1);
        pair.sync();
        assertNotEq(pair.price0CumulativeLast(), 0, "is zero");
        vm.warp(2);
        pair.sync();
        assertNotEq(pair.price0CumulativeLast(), 0, "is zero");
    }

    function testCumulativePrices() public {
        vm.warp(0);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);
        pair.mint(address(this));

        // 최초 가격 가져오기
        (uint initialPrice0, uint initialPrice1) = calculateCurrentPrice();

        // 0 초 후
        pair.sync();
        assertCumulativePrices(0, 0);

        // 1 초 후
        vm.warp(1);
        pair.sync();
        assertBlockTimestampLast(1);
        assertCumulativePrices(initialPrice0, initialPrice1);

        // 2 초 후
        vm.warp(2);
        pair.sync();
        assertBlockTimestampLast(2);
        assertCumulativePrices(initialPrice0 * 2, initialPrice1 * 2);

        // 3 초 후
        vm.warp(3);
        pair.sync();
        assertBlockTimestampLast(3);
        assertCumulativePrices(initialPrice0 * 3, initialPrice1 * 3);

        // 풀에 예치된 토큰 비율 변화 -> 가격 변화
        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);
        pair.mint(address(this)); //lp토큰 발행

        // 변경된 가격 가져오기
        (uint newPrice0, uint newPrice1) = calculateCurrentPrice();

        // 0 초 후 = 위에랑 똑같음
        assertCumulativePrices(initialPrice0 * 3, initialPrice1 * 3);

        // 1 초 후 = 0 초 후 + 변경 가격 * 1초
        vm.warp(4);
        pair.sync();
        assertBlockTimestampLast(4);
        assertCumulativePrices(initialPrice0 * 3 + newPrice0, initialPrice1 * 3 + newPrice1);

        // 2 초 후 = 0 초 후 + 변경 가격 * 2초
        vm.warp(5);
        pair.sync();
        assertBlockTimestampLast(5);
        assertCumulativePrices(initialPrice0 * 3 + newPrice0 * 2, initialPrice1 * 3 + newPrice1 * 2);


        // 3 초 후 = 0 초 후 + 변경 가격 * 3초
        vm.warp(6);
        pair.sync();
        assertBlockTimestampLast(6);
        assertCumulativePrices(initialPrice0 * 3 + newPrice0 * 3, initialPrice1 * 3 + newPrice1 * 3);
    }
}