// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../lib/solmate/src/tokens/ERC20.sol";
import "../interfaces/IERC20.sol";
import "../libraries/Math.sol";
import "../libraries/UQ112x112.sol";
import "../interfaces/IHySwapPair.sol";



contract HySwapPair is ERC20, IHySwapPair {
    // Errors
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error TransferFailed();
    error InsufficientOutputAmount();
    error InsufficientLiquidity();
    error InsufficientInputAmount();
    error InvalidK();


    // 'using X for Y': 라이브러리의 함수 X를 타입 Y로 사용
    using UQ112x112 for uint224;

    uint constant MIN_LIQUIDITY = 1000;

    // 토큰 잔액 -> 가스비 절감을 위해 uint112로 저장함
    uint112 private reserve0;
    uint112 private reserve1;

    // 페어의 토큰 주소
    address public token0;
    address public token1;

    // TWAP 계산을 위해 필요한 변수
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint32 private blockTimestampLast; // 마지막 스왑의 timestamp를 기록

    address public factory;

    // constructor(address token0_, address token1_) ERC20("HySwapPair", "HY_V2", 18) {// test 용
    //     factory = msg.sender;
    //     token0 = token0_;
    //     token1 = token1_;
    // }

    constructor() ERC20("HySwapPair", "HY_V2", 18) {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'HySwap: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
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
        return (reserve0, reserve1, uint32(block.timestamp));
    }

    function _update(uint balance0, uint balance1, uint112 reserve0_, uint112 reserve1_) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");

        // unchecked keyword: 솔리디티 0.8.0 이상부터 사용 가능
        // 런타임시에 자동 오버/언더플로우 체크 해제
        // 검사안하는 이유? 변화를 감지하기 위한 용도라서 절대값이 자동으로 초기화되면 오히려 좋다
        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;
            
            if (timeElapsed > 0 && reserve0_ > 0 && reserve1_ > 0) {
                /*
                    price0CumulativeLast = 토큰0 대비 토큰1의 가격
                    price1CumulativeLast = 토큰1 대비 토큰0의 가격
                    UQ112x112.encode() => reserve 값을 고정 소수점 형태로 인코딩
                    UQ112x112.uqdiv() => 두 reserve 간의 비율을 계산
                */

                // timeElapsed를 곱해서 시간 가중 (time weighted)
                price0CumulativeLast += uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed; 
                price1CumulativeLast += uint256(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) * timeElapsed;
            }
        }

        // reserve값 업데이트
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        // blockTimestampLast 최신화
        blockTimestampLast = uint32(block.timestamp);
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

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) public {
        if (amount0Out == 0 && amount1Out == 0)
            revert InsufficientOutputAmount();

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();

        if (amount0Out > reserve0_ || amount1Out > reserve1_)
            revert InsufficientLiquidity();

        uint256 balance0 = IERC20(token0).balanceOf(address(this)) - amount0Out;
        uint256 balance1 = IERC20(token1).balanceOf(address(this)) - amount1Out;


        if (balance0 * balance1 < uint256(reserve0_) * uint256(reserve1_))
            revert InvalidK();

        _update(balance0, balance1, reserve0_, reserve1_);

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);
    }

    function swap2(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) public {
        if (amount0Out == 0 && amount1Out == 0)
            revert InsufficientOutputAmount();

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();

        if (amount0Out > reserve0_ || amount1Out > reserve1_)
            revert InsufficientLiquidity();

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > reserve0 - amount0Out
            ? balance0 - (reserve0 - amount0Out)
            : 0;
        uint256 amount1In = balance1 > reserve1 - amount1Out
            ? balance1 - (reserve1 - amount1Out)
            : 0;

        if (amount0In == 0 && amount1In == 0) revert InsufficientInputAmount();

        // Adjusted = balance before swap - swap fee; fee stays in the contract
        uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);


        if (
            balance0Adjusted * balance1Adjusted <
            uint256(reserve0_) * uint256(reserve1_) * (1000**2)
        ) revert InvalidK();

        _update(balance0, balance1, reserve0_, reserve1_);
    }

    function sync() public {
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0_, reserve1_);
    }
}