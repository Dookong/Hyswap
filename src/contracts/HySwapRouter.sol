pragma solidity ^0.8.13;

import "../interfaces/IHySwapRouter.sol";
import "../libraries/HySwapLibrary.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IFactory.sol";
import "../contracts/HySwapPair.sol";

contract HySwapRouter  {
    error InsufficientAAmount();
    error InsufficientBAmount();
    error InsufficientOutputAmount();
    error ExcessiveInputAmount();
    address public immutable factory;

    constructor(address hySwapFactory) {
        factory = hySwapFactory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,// 유저가 보내고자 하는 토큰의 양
        uint amountBDesired,
        uint amountAMin,// 유저가 최소한으로 보내고자 하는 토큰의 양
        uint amountBMin,
        address to
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        if(IFactory(factory).getPair(tokenA, tokenB) == address(0)){ // 페어가 존재하지 않으면
            IFactory(factory).createPair(tokenA, tokenB); // 페어를 생성한다.
        }
        (amountA, amountB) = _calculateLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        HySwapPair pair = HySwapPair(HySwapLibrary.pairFor(factory, tokenA, tokenB));

        TransferHelper.safeTransferFrom(tokenA, msg.sender, address(pair), amountA); // 유저가 보내고자 하는 토큰의 양을 pair contract로 전송한다.
        TransferHelper.safeTransferFrom(tokenB, msg.sender, address(pair), amountB);
        liquidity = pair.mint(to);
    }

    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired, // 유저가 보내고자 하는 토큰의 양
        uint amountBDesired,
        uint amountAMin, // 유저가 최소한으로 보내고자 하는 토큰의 양
        uint amountBMin
    ) internal view returns (uint amountA, uint amountB){
        (uint256 reserveA, uint256 reserveB) = HySwapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) { // 페어에 유동성이 없으면 유저가 보내고자 하는 토큰의 양을 그대로 유동성에 포함시킨다.
            (amountA, amountB) = (amountADesired, amountBDesired);
        }
        else {
            uint amountBOptimal = HySwapLibrary.quote(amountADesired, reserveA, reserveB); // 기존 유동성 내의 토큰 비율과 맞추기.
            if (amountBOptimal <= amountBDesired) {
                if(amountBOptimal <= amountBMin) revert InsufficientBAmount(); // 유저가 최소한으로 보내고자 하는 토큰의 양보다 적으면 에러를 발생시킨다.
                (amountA, amountB) = (amountADesired, amountBOptimal);
            }
            else {
                uint amountAOptimal = HySwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                if(amountAOptimal <= amountAMin) revert InsufficientAAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    

    // 유동성 제거 함수. 
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity, // lp token의 양
        uint amountAMin,// 유저가 최소한으로 받고자 하는 토큰의 양(슬리피지 고려)
        uint amountBMin,
        address to // 유저의 주소
    ) external returns (uint amountA, uint amountB){
        // 유저의 lp토큰을 pair contract에서 소각하고, 상응하는 토큰을 유저에게 전송해야 한다. 
        address pair  = HySwapLibrary.pairFor(factory, tokenA, tokenB);

        HySwapPair(pair).transferFrom(msg.sender, pair, liquidity); // msg.sender에서 pair contract에 보낸다.  
       (amountA, amountB) = HySwapPair(pair).burn(to); // pair contract에서 lp토큰을 소각한다.

        if(amountA < amountAMin){// 유동성에 해당하는 토큰의 양이 유저가 최소한으로 받고자 하는 토큰의 양보다 적으면
            revert InsufficientAAmount(); // 에러를 발생시킨다.
        }
        if(amountB < amountBMin){
            revert InsufficientBAmount();
        }
    }

    //  input이 정확히 알 때 사용하는 swap함수.
    function swapExactTokensForTokens(
        uint256 amountIn, // 유저가 보내고자 하는 토큰의 양
        uint256 amountOutMin, // 유저가 최소한으로 받고자 하는 토큰의 양
        address[] calldata path, // 토큰 주소들이 들어있는 배열
        address to // 유저의 주소
    ) public returns (uint256 [] memory amounts) {
        amounts = HySwapLibrary.getAmountsOut(factory, amountIn, path); // path의 모든 amountsout을 return한다.
        if(amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount(); // 유저가 최소한으로 받고자 하는 토큰의 양보다 적으면 에러를 발생시킨다.
        TransferHelper.safeTransferFrom(path[0], msg.sender, HySwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]); // 유저가 보내고자 하는 토큰의 양을 pair contract로 전송한다.
        _swap(amounts, path, to); // 토큰을 토큰으로 스왑한다.
    }
    // output이 정확히 알 때 사용하는 swap함수. 
    function swapTokensForExactTokens(
        uint256 amountOut, 
        uint256 amountInMax, 
        address[] calldata path, 
        address to
    ) public returns (uint256[] memory amounts) {
        amounts = HySwapLibrary.getAmountsIn(factory, amountOut, path); // path의 모든 amountsin을 return한다.
        if(amounts[amounts.length - 1] > amountInMax) revert ExcessiveInputAmount(); // 유저가 최대한으로 보내고자 하는 토큰의 양보다 많으면 에러를 발생시킨다.
        TransferHelper.safeTransferFrom(path[0], msg.sender, HySwapLibrary.pairFor(factory, path[0], path[1]), amounts[0]); // 유저가 보내고자 하는 토큰의 양을 pair contract로 전송한다.
        _swap(amounts, path, to); // 토큰을 토큰으로 스왑한다.      
    }

// path을 따라서 하나씩 swap해 나가는 함수이다.
    function _swap(uint256[] memory amounts, address[] memory path, address to_) internal {
        for (uint256 i; i < path.length - 1; i++){
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = HySwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? HySwapLibrary.pairFor(factory, output, path[i + 2]) : to_;
            HySwapPair(HySwapLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
}
