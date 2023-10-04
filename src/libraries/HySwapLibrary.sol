pragma solidity ^0.8.13;

import "../interfaces/IHySwapPair.sol";
import "../contracts/HySwapPair.sol";

error InvalidPath();
error InsufficientAmount();


library HySwapLibrary{
    error InsufficientLiquidity();

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
    //amountIn(delta x)에 대한 amountOut(delta y)를 계산하는 함수
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        if(amountIn == 0) revert InsufficientAmount();
        if(reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();// 페어에 유동성이 없으면 에러를 발생시킨다.

        uint amountInWithFee = amountIn * 997; // 0.3%의 수수료를 반영한다. r * delta x
        uint numerator = amountInWithFee * reserveOut; // r * delta x * y = r * delta y
        uint denominator = (reserveIn * 1000) + amountInWithFee; // x * 1000 + r * delta x

        return numerator / denominator;
    }

    function getAmountsOut(address factory, uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        if(path.length < 2) revert InvalidPath();
        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i = 0; i < path.length - 1; i++){
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    //amountOut(delta y)에 대한 amountIn(delta x)를 계산하는 함수
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        if(amountOut == 0) revert InsufficientAmount();
        if(reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();// 페어에 유동성이 없으면 에러를 발생시킨다.

        uint numerator = reserveIn * amountOut * 1000; // x * y * 1000 = x * delta y
        uint denominator = (reserveOut - amountOut) * 997; // (y - delta y) * 997 = r * delta x
        return (numerator / denominator) + 1; // 1을 더하는 이유는 solidity에서 소수점을 버리기 때문이다.
    }   

    function getAmountsIn(address factory, uint amountOut, address[] memory path) public view returns (uint[] memory amounts) {
        if(path.length < 2) revert InvalidPath();
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for(uint i = amounts.length - 1; i > 0; i--){
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}