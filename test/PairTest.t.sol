// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/contracts/Factory.sol";

contract A{}
contract B{}
contract C{}

error testError();

contract PairTest is Test{
    event myAddr(address);

    HySwapPair pair;
    ERC20Mintable token0;
    ERC20Mintable token1;
    Factory factory;
    A a;

    // 기본 설정
    function setUp() public {
        token0 = new ERC20Mintable("A", "TKA");
        token1 = new ERC20Mintable("B", "TKB");

        (token0, token1) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);

        emit myAddr(address(a));
        emit myAddr(address(token0));
        emit myAddr(address(token1));

        factory = new Factory(address(this));
        pair = HySwapPair(factory.createPair(address(token0), address(token1)));

        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));

        // revert testError();
    }

    // 풀에 예치된 토큰 개수 확인
    function assertReserves(uint112 expectedReserve0, uint112 expectedReserve1) internal {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        (uint112 _reserve0, uint112 _reserve1) = address(token0) < address(token1) 
        ? (reserve0, reserve1) : (reserve1, reserve0);
        assertEq(_reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(_reserve1, expectedReserve1, "unexpected reserve1");
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

        assertEq(pair.balanceOf(address(this)), 0); // pair의 lp토큰 잔고 = 0 <- 소각했으니까
        assertReserves(1000, 1000); // 미니멈이 1000개는 회수 못해서 풀에 남아 있음
        assertEq(pair.totalSupply(), 1000); // min == 1000
        assertEq(token0.balanceOf(address(this)), 10 ether - 1000); //회수해간 토큰 개수 = 처음 공급했던거 - min
        assertEq(token1.balanceOf(address(this)), 10 ether - 1000); //회수해간 토큰 개수 = 처음 공급했던거 - min
    }

    // 스왑
    function testSwapBasicScenario() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        uint256 amountOut = 0.181322178776029826 ether;
        token0.transfer(address(pair), 0.1 ether);
        pair.swap(0, amountOut, address(this), "");

        assertEq(
            token0.balanceOf(address(this)),
            10 ether - 1 ether - 0.1 ether,
            "unexpected token0 balance"
        );
        assertEq(
            token1.balanceOf(address(this)),
            10 ether - 2 ether + amountOut,
            "unexpected token1 balance"
        );
        assertReserves(1 ether + 0.1 ether, uint112(2 ether - amountOut));
    }
    
    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function testSwapZeroOut() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        vm.expectRevert(encodeError("InsufficientOutputAmount()"));
        pair.swap(0, 0, address(this), "");
    }

    function testSwapUnpaidFee() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        token0.transfer(address(pair), 0.1 ether);

        vm.expectRevert(encodeError("InvalidK()"));
        pair.swap2(0, 0.181322178776029827 ether, address(this), "");
    }
}