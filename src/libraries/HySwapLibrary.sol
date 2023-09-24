pragma solidity ^0.8.13;

import "../interfaces/IHySwapPair.sol";
import "../contracts/HySwapPair.sol";

library HySwapLibrary{

    // sortTokens 함수는 토큰 A와 토큰 B를 정렬하는 함수
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'HySwapLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'HySwapLibrary: ZERO_ADDRESS');
    }

    // gas 아끼기 위한 행위 == HyswapFactory(factory).getPair(tokenA, tokenB) 와 같은 행위
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            keccak256(type(HySwapPair).creationCode) // init code hash 
        )))));
    }
    // getReserves 함수는 토큰 A와 토큰 B의 개수 반환
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IHySwapPair(pairFor(factory, token0, token1)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    // quote 함수는 기존 유동성 내의 토큰 비율과 맞추기 위한 함수
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) { 
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = (amountA * (reserveB)) / reserveA;
    }
}