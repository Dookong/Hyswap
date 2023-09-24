// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";

contract PairTest is Test{
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

    // 최초 유동성 공급시
    function testMintBootstrap() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); //LP토큰 +1

        assertEq(pair.totalSupply(), 1 ether); // 총 1개 생성됨
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000); // total - minimum
        assertReserves(1 ether, 1 ether);
    }

    // 이미 유동성이 존재할 때 추가 공급시
    function testMintAlreadyExists() public {
        token0.transfer(address(pair), 1 ether); //PairTest에서 HySwapPair로 1개 전송
        token1.transfer(address(pair), 1 ether); //PairTest에서 HySwapPair로 1개 전송

        pair.mint(address(this)); //LP토큰 +1

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint(address(this)); //LP토큰 +1

        assertEq(pair.totalSupply(), 3 ether); // 총 3개 생성됨
        assertEq(pair.balanceOf(address(this)), 3 ether - 1000); // total - minimum
        assertReserves(3 ether, 3 ether);
    }

    // 1:1 비율에 안맞게 유동성 공급시
    function testMintUnbalanced() public {
        token0.transfer(address(pair), 1 ether); //PairTest에서 HySwapPair로 1개 전송
        token1.transfer(address(pair), 1 ether); //PairTest에서 HySwapPair로 1개 전송

        pair.mint(address(this)); //LP토큰 +1
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); //LP토큰 +1 -> 2:1로 공급해도 lp는 똑같이 1개만 발행함!
        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(3 ether, 2 ether);
    }

    // 소각
    function testBurn() public {
        //유동성 공급
        token0.transfer(address(pair), 1 ether); //PairTest에서 HySwapPair로 1개 전송 (유동성 공급)
        token1.transfer(address(pair), 1 ether); //PairTest에서 HySwapPair로 1개 전송 (유동성 공급)
        pair.mint(address(this)); //PairTest가 유동성 공급의 대가로 lp 토큰 받아감

        //유동성 회수
        uint liquidity = pair.balanceOf(address(this)); // PairTest가 소유한 lp token 수량 = liquidity
        pair.transfer(address(pair), liquidity); //풀에 lp token 반납
        pair.burn(address(this)); // pair가 PairTest에게 맡겼던 토큰 돌려줌

        // assertEq(pair.balanceOf(address(this)), 0); // pair의 lp토큰 잔고 = 0 <- 소각했으니까
        // assertReserves(1000, 1000); // ?
        // assertEq(pair.totalSupply(), 1000); // 총 공급 1000개
        // assertEq(token0.balanceOf(address(this)), 10 ether - 1000);
        // assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
    }
}