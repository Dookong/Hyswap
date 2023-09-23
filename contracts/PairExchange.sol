pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IPairExchange.sol";
import "./interfaces/IFactory.sol";
import "./libraries/Math.sol";


contract PairExchange is IPairExchange {

    /* 
     * 팩토리에서 페어를 생성하면, 페어는 페어의 주소를 가지고 있거나 얻을 수 있어야 한다.
     * 페어를 swap하고 유동성을 추가하거나 제거할 수 있어야 한다.
     * 수수료를 받을 수 있어야 한다.
    */

    // 페어의 토큰
    address token0;
    address token1;

    IFactory factory; 

    // pair 토큰 별 잔액
    uint reserve0;
    uint reserve1;
    uint kLast;


    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    
    constructor (address _token0, address _token1) {// unique는 나중에 구현. 
        // 페어를 생성한다.
        token0 = _token0;
        token1 = _token1;
        factory = IFactory(msg.sender);// msg.sender는 팩토리 주소
    }

    function getReserves() public view returns (uint, uint) { // view는 가스비 절약가능
        return (reserve0, reserve1);
    }

    function _update(uint balance0, uint balance1, uint _reserve0, uint _reserve1) private pure {
        // 페어의 토큰을 업데이트한다.
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        
        _reserve0 = balance0;
        _reserve1 = balance1;
    }

    function swap() external {
        // 페어의 토큰을 스왑한다.
        

    } 

    function _calculateK(uint _reserve0, uint _reserve1) private returns (bool feeOn) {
        // 페어의 토큰의 K값을 계산한다. (mint, burn에서 사용)
        address feeAddress = factory.feeAddress();
        feeOn = feeAddress != address(0);
        uint _kLast = kLast; // gas savings

        if(feeOn){
            if(_kLast != 0){
                uint rootK = Math.sqrt(uint(_reserve0) * _reserve1);
                
                uint rootKLast = Math.sqrt(_kLast);
                if(rootK > rootKLast){
                    uint numerator = totalSupply() * (rootK - rootKLast);
                    uint denominator = rootK * 5 + rootKLast;
                    uint liquidity = numerator / denominator;
                    if(liquidity > 0){
                        _mint(feeAddress, liquidity);
                    }
                }
            }
        }else if(_kLast != 0){
            kLast = 0;
        }



        



        return balance0 * balance1;
    }

    function mint(address to) external {
        // 페어의 토큰을 발행한다.

    }

    function burn() external {
        // 페어의 토큰을 소각한다.
    }

    function addLiquidity(uint256 maxTokens) external payable {
        // 페어에 유동성을 추가한다.
    }

    function removeLiquidity(uint lpTokenAmount) external {
        // 페어의 유동성을 제거한다.
    }
}