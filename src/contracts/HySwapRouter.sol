pragma solidity ^0.8.13;

import "../interfaces/IHySwapRouter.sol";
import "../libraries/HySwapLibrary.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IFactory.sol";



contract HySwapRouter  {

    address public immutable factory;

    constructor(address hySwapFactory) {
        factory = hySwapFactory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        if(IFactory(factory).getPair(tokenA, tokenB) == address(0)){
            IFactory(factory).createPair(tokenA, tokenB);
        }
        (amountA, amountB) = _calculateLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        HySwapPair pair = HySwapPair(HySwapLibrary.pairFor(factory, tokenA, tokenB));

        TransferHelper.safeTransferFrom(tokenA, msg.sender, address(pair), amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, address(pair), amountB);
        liquidity = pair.mint(to);
        // require(liquidity==pair.mint(to));
    }

    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view returns (uint amountA, uint amountB){
        (uint256 reserveA, uint256 reserveB) = HySwapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        }
        else {
            uint amountBOptimal = HySwapLibrary.quote(amountADesired, reserveA, reserveB); // 기존 토큰 비율과 맞추기.
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "HySwapRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            }
            else {
                uint amountAOptimal = HySwapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "HySwapRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB){

    }
    
}
