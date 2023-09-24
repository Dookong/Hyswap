// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC20.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Math.sol";

// Errors
error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();
error InsufficientOutputAmount();
error InsufficientLiquidity();
error InvalidK();

contract HySwapPair is ERC20{
    uint constant MIN_LIQUIDITY = 1000;

    uint112 private reserve0;
    uint112 private reserve1;

    address public token0;
    address public token1;

    constructor(address token0_, address token1_) ERC20("HySwapPair", "HY_V2", 18) {
        token0 = token0_;
        token1 = token1_;
    }

    function mint(address to) external returns (uint liquidity){
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        Math math_module = new Math();

        uint balance0 = IERC20(token0).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token0의 개수
        uint balance1 = IERC20(token1).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token1의 개수
        uint amount0 = balance0 - reserve0_;
        uint amount1 = balance1 - reserve1_;

        // 최초 공급시
        if (totalSupply == 0) {
            liquidity = math_module.sqrt(amount0 * amount1) - MIN_LIQUIDITY;
            _mint(address(0), MIN_LIQUIDITY);
        }
        // 추가 공급시
        else {
            liquidity = math_module.min(
                (amount0 * totalSupply) / reserve0_,
                (amount1 * totalSupply) / reserve1_
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();
        _mint(to, liquidity);
        _update(balance0, balance1, reserve0_, reserve1_);
    }

    function getReserves() public view returns (uint112, uint112, uint32){
        return (reserve0, reserve1, 0);
    }

    function _update(uint balance0, uint balance1, uint112 reserve0_, uint112 reserve1_) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));

        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert TransferFailed();
    }

    function burn(address to) external returns (uint amount0, uint amount1){
        uint balance0 = IERC20(token0).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token0의 개수
        uint balance1 = IERC20(token1).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token1의 개수

        /*
            원래는 msg.sender가 보유한 수량을 그대로 사용했으나, 이렇게 하면 sender의 명시적 동의가 없기 때문에 위험하다.
            호출자가 상위 레벨에서 pair 컨트랙트에게 lp token을 보내면, 그 수량을 그대로 사용하는 것으로 대체한다.
        */
        uint liquidity = balanceOf[address(this)]; // pair 컨트랙트가 보유한 lp토큰의 개수 = high level에서 호출자가 보유한 lp토큰의 개수

        // 호출자가 유동성을 회수하고 가져갈 각 토큰의 양 = [호출자가 보유한 lp 토큰의 개수 / 전체 lp 토큰 발행량](기여도) * 풀에 존재하는 전체 토큰의 양
        amount0 =  (liquidity * balance0) / totalSupply;
        amount1 =  (liquidity * balance1) / totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned(); // 예외 처리

        _burn(address(this), liquidity); // lp토큰 소각부터 하고
        _safeTransfer(token0, to, amount0); // 호출자에게 토큰 돌려주기
        _safeTransfer(token1, to, amount1); // 호출자에게 토큰 돌려주기

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        _update(balance0, balance1, reserve0_, reserve1_); //풀에 잔존하는 토큰 개수 업데이트
    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external{
        if (amount0Out == 0 && amount1Out == 0)
            revert InsufficientOutputAmount();
        
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves(); // 풀에 예치되어 있는 토큰 개수

        if (amount0Out > reserve0_ || amount1Out > reserve1_) // 내줘야 할 양보다 예치된 양이 적으면 에러 발생
            revert InsufficientLiquidity();
        
        // 스왑 후 잔고 = 기존 잔고 - out
        uint balance0 = IERC20(token0).balanceOf(address(this)) - amount0Out;
        uint balance1 = IERC20(token1).balanceOf(address(this)) - amount1Out;

        //Constant Product 체크 -> 스왑 후의 K >= 스왑 전의 K
        if (balance0 * balance1 < uint256(reserve0_) * uint256(reserve1_))
            revert InvalidK();
        
        _update(balance0, balance1, reserve0_, reserve1_); //풀에 잔존하는 토큰 개수 업데이트

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out); // out만큼 지급
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);
    }
}