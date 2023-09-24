pragma solidity ^0.8.13;

import "../interfaces/IHySwapRouter.sol";
import "../libraries/HySwapLibrary.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IFactory.sol";
import "../contracts/HySwapPair.sol";



error InsufficientAAmount();
error InsufficientBAmount();


contract HySwapRouter  {

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

        HySwapPair(pair).transferFrom(msg.sender, address(this), liquidity); // 유저의 lp토큰을 pair contract에서 가져온다.
       (amountA, amountB) = HySwapPair(pair).burn(address(this)); // pair contract에서 lp토큰을 소각한다.

        if(amountA < amountAMin){// 유동성에 해당하는 토큰의 양이 유저가 최소한으로 받고자 하는 토큰의 양보다 적으면
            revert InsufficientAAmount(); // 에러를 발생시킨다.
        }
        if(amountB < amountBMin){
            revert InsufficientBAmount();
        }
    }
}
