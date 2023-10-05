# HySwap(하이스왑)

### **2023년도 한양대학교 컴퓨터소프트웨어학부 졸업프로젝트**

프로젝트 주제: 이더리움 토큰을 활용한 블록체인 어플리케이션 개발

프로젝트 기간: 2023.03 ~ 2023.10

참여자: 2018008468 박현준 / 2018008895 이성구

---

# 하이스왑

먼저 [UniSwap](https://github.com/Uniswap)은 최초의 이더리움 기반 온체인 AMM 프로토콜이면서, 2023년 현재 가장 성공적인 디파이(DeFi) 프로젝트입니다. HySwap에서는 UniSwap v2 수준의 기능들을 구현했습니다.

- 개발 언어: Solidity
- 프레임워크: [*Foundry*](https://github.com/foundry-rs/foundry)
- ERC20 템플릿: *[solmate](https://github.com/transmissions11/solmate)*

## 테스트

1. `git clone https://github.com/Dookong/Hyswap.git`
2. `curl -L https://foundry.paradigm.xyz | bash`
3. `foundryup`
4. `forge test`

## 배포

주소 업데이트 예정

---

## 핵심 개념

### CPMM(Constant Product Market Maker)

디파이에서 탈중앙화된 방식으로 두 토큰 간의 교환을 진행하기 위해서,  AMM(Auto Market MAker) 알고리즘으로 CPMM을 사용한다. Constant Product란 유동성 풀에 예치된 두 토큰 수량의 곱이 스왑 전후로 일정해야한다라는 의미를 갖는다. 수식으로 풀어쓰면 다음과 같다.

$$
x * y = k
$$

$$
(x + \Delta x )(y - \Delta y) = k
$$

하지만 스왑 수수료를 부과하여 유동성 풀에 일부 토큰을 남기도록 구성했고, 실제 스왑 후에는 k값이 미세하게 증가하는 현상을 반영하여 아래와 같은 공식을 적용했다.

$$
(x + r\Delta x )(y - \Delta y) = k \leftarrow r = 1 - fee
$$

x토큰을 예치한 대가로 받아갈 y토큰의 수량, Δy에 대해서 풀면 아래와 같다. 만약 수수료가 0.2%라면 r = 1 - 0.002 = 0.998이 된다.

$$
\Delta y = \frac{yr\Delta x}{x + r\Delta x}
$$

위 수식을 Solidity 코드로 작성한 것이 getAmountOut() 함수이다.

```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
public pure returns (uint256) {
        if(amountIn == 0) 
					revert InsufficientAmount();
        if(reserveIn == 0 || reserveOut == 0) 
					revert InsufficientLiquidity();// 페어에 유동성이 없으면 에러를 발생시킨다.

        uint amountInWithFee = amountIn * 997; // 0.3%의 수수료를 반영한다. r * delta x
        uint numerator = amountInWithFee * reserveOut; // r * delta x * y = r * delta y
        uint denominator = (reserveIn * 1000) + amountInWithFee; // x * 1000 + r * delta x

        return numerator / denominator;
    }
```

### 유동성 공급 및 회수

원활한 스왑이 진행되기 위해서는 풀에 각 토큰이 충분히 예치되어 있어야 하고, 이를 유동성(liquidity)라고 한다.

유동성 공급시에 LP Token을 발행하고, 유동성 회수시에 LP Token을 회수한다.

**유동성 공급**

공급시에는 기본적으로 전체 유동성에 기여한 비율에 따라 LP Token을 발행해야 한다. 다만 최초 공급시에는 유의미한 기여도를 계산할 수 없으므로 기하 평균을 사용하여 유동성 비율의 영향력을 상쇄한다. 

1. 최초 유동성 공급시
    
    발행할 LP Token의 수량 =  예치된 두 토큰 수량의 기하 평균
    
2. 기존에 유동성이 존재할 때
    
    발행할 LP Token의 수량 =  전체 LP 토큰 발행량 * 새로 공급한 토큰 수량이 전체 풀에서 차지하는 비율
    

이를 수식으로 정리하면 아래와 같다.

$$
1. LP_{발행} = \sqrt{token_x * token_y}
$$

$$
2. LP_{발행} = Total_{LP} * Token_{공급}/Reserve
$$

그리고 이를 다시 Solidity 코드로 작성하면 아래와 같다.

```solidity
function mint(address to) external returns (uint liquidity){
    ...
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
		...
    }
```

**유동성 회수**

회수시에는 공급 과정을 정반대로 진행한다.

$$
Token_{회수} = Reserve * Balance_{LP} / Total_{LP}
$$

```solidity
function burn(address to) external returns (uint amount0, uint amount1){
      uint balance0 = IERC20(token0).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token0의 개수
      uint balance1 = IERC20(token1).balanceOf(address(this)); //pair 컨트랙트가 가지고 있는 token1의 개수
      uint liquidity = balanceOf[address(this)]; // pair 컨트랙트가 보유한 lp토큰의 개수 = high level에서 호출자가 보유한 lp토큰의 개수

      // 호출자가 유동성을 회수하고 가져갈 각 토큰의 양 = [호출자가 보유한 lp 토큰의 개수 / 전체 lp 토큰 발행량](기여도) * 풀에 존재하는 전체 토큰의 양
      amount0 =  (liquidity * balance0) / totalSupply;
      amount1 =  (liquidity * balance1) / totalSupply;

      if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned(); // 예외 처리

      _burn(address(this), liquidity); // lp토큰 소각부터 하고
      _safeTransfer(token0, to, amount0); // 호출자에게 토큰 돌려주기
      _safeTransfer(token1, to, amount1); // 호출자에게 토큰 돌려주기

    ...
    }
```

### ERC20 ↔ ERC20 교환하기

초기 단계의 UniSwap에서는 기축 통화로 ETH를 사용했다. 그래서 ETH ↔ ERC20 간의 스왑만을 고려하는 것이 전부였고 구현이 비교적 간단했다. 하지만 사용자 입장에서 가스비를 이중으로 지불해야 한다는 맹점이 존재했고, 이를 극복하기 위해서 ERC20 페어 간 스왑을 지원하도록 개선했다.

**ETH를 기축 통화로 사용했을 때(v1)**

```solidity
// ERC20 -> ERC20
    function tokenToTokenSwap(uint tokenSold, uint minTokenBought, uint minEthBought, address _tokenAddress) public payable {
        address toTokenExchangeAddress = factory.getExchange(_tokenAddress);

        uint256 ethOutputAmount = getOutputAmount(tokenSold, token.balanceOf(address(this)), address(this).balance);
        require(ethOutputAmount >= minEthBought, "Insufficient ouputAmount!");

        IERC20(token).transferFrom(msg.sender, address(this), tokenSold);

        //인터페이스 정의
        IExchange(toTokenExchangeAddress).ethToTokenTransfer{value: ethOutputAmount}(minTokenBought, msg.sender);
    }
```

**ERC20 토큰 간 직접 교환할 때(v2)**

```solidity
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
```

### 가격 오라클

외부 데이터를 블록체인 네트워크 안으로 가지고 올 때 발생하는 문제를 오라클 문제라고 한다. 다른 디앱에서 ERC20 토큰의 가격 정보를 활용하고자 중앙화 거래소의 API를 호출할 때도 다양한 문제가 발생할 수 있다. 데이터를 제공하는 API 서버의 가용성 문제, 그리고 오프체인 데이터의 출처에 대한 신뢰도 문제가 대표적이다.

그런데 온체인 어플리케이션인 HySwap에서 직접 가격 정보를 제공하고, 이 과정이 스마트 컨트랙트로 작성되어 투명하게 공개된다면 누구나 신뢰할 수 있고 간편하게 이용할 수 있을 것이다. 그리고 신뢰할 수 있는 가격 정보를 제공하기 위해서 이전 모든 스왑의 가격 기록을 보관한다.

순간적인 가격은 조작될 위험이 있기 때문에, 신뢰도와 안정성을 보장하기 위해서 누적 가격을 사용하는 것이 메인 아이디어이다. 누적 가격은 유동성 풀 컨트랙트의 역사의 ‘매초 가격의 합계’로 정의된다.

$$
a_i = \sum^t_{i=1}p_i
$$

이 접근 방식을 사용하여 두 시점 [t1,t2] 사이의 시간 가중 평균 가격을 구할 수 있다. 각 시점의 누적 가격의 편차를 각 시점의 편차로 나눈다.

$$
p_{t1, t2} = \frac{a_{t_2}-a_{t_1}}{t_2 - t_1}
$$

해당 개념을 반영하기 위해서 유동성 풀 컨트랙트의 _update() 함수에서 각 토큰의 누적 가격을 계산하여 최신화하도록 구현한다.

```solidity
function _update(uint balance0, uint balance1, 
	uint112 reserve0_, uint112 reserve1_) private {
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
        // blockTimestampLast 최신화
        blockTimestampLast = uint32(block.timestamp);
    }
```

---

## 고려 사항

### 스마트 컨트랙트 배포를 위해서 Foundry를 채택한 이유?

Truffle이나 Hardhat과 다르게 Solidity만으로 테스트 코드를 작성할 수 있어서 *ethers* 라이브러리에 대한 의존성을 없앨 수 있었다. 또한 컴파일과 테스팅에 소요되는 시간이 훨씬 더 단축되는 효과가 있었다.

**Hardhat에서 테스트 코드를 작성했을 때(before)**

```jsx
import { ethers } from "hardhat"
import { expect } from "chai";
import { BigNumber } from "ethers";
import { Exchange } from "../typechain-types/contracts/Exchange"
import { Token } from "../typechain-types/contracts/Token";

const toWei = (value: number) => ethers.utils.parseEther(value.toString());
const toEther = (value: BigNumber) => ethers.utils.formatEther(value);
const getBalance = ethers.provider.getBalance;

...

describe("addLiquidity", async () => {
        it ("addLiquidity",  async() => {
            await token.approve(exchange.address, toWei(1000));
            await exchange.addLiquidity(toWei(1000), {value: toWei(1000)});

            //test
            expect(await getBalance(exchange.address)).to.equal(toWei(1000));
            expect(await token.balanceOf(exchange.address)).to.equal(toWei(1000));
        })
    });
```

**Foundry에서 테스트 코드를 작성했을 때(after)**

```solidity
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/contracts/HySwapRouter.sol";
import "./ERC20Mintable.sol";
import "../src/contracts/HySwapPair.sol";
import "../src/contracts/Factory.sol";

contract AddLiquidityTest is Test {
    ERC20Mintable public tokenA;
    ERC20Mintable public tokenB;

    HySwapRouter router;
    Factory factory;

    ...

    function testAddLiquidity() public {
        router.addLiquidity(address(tokenA), address(tokenB), 1 ether, 1 ether, 1 ether, 1 ether, address(this));

        HySwapPair pair = HySwapPair(factory.getPair(address(tokenA), address(tokenB)));
        assertEq(pair.balanceOf(address(this)), 999999999999999000); // minimum liquidity 1000

        assertEq(tokenA.balanceOf(address(this)), 19 ether);
        assertEq(tokenB.balanceOf(address(this)), 19 ether);

        assertEq(tokenA.balanceOf(address(pair)), 1 ether);
        assertEq(tokenB.balanceOf(address(pair)), 1 ether);
    }
}
```

### 상속받을 ERC20 구현체로 solmate 라이브러리를 채택한 이유?

UniSwap에서는 ERC20 컨트랙트를 직접 구현했지만, 테스트를 거친 템플릿을 활용하면 더 빠르고 안정적으로 Swap 컨트랙트 구현에 집중할 수 있었다. 템플릿 선택지로는 *openzeppelin*, *solmate* 등이 있었고, Swap 구현의 편의를 위해서 영주소로의 토큰 전송을 제한하지 않는 ***solmate***를 채택했다.

**Uniswap/v2-core/contracts/UniswapV2ERC20.sol**

```solidity
function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }
```

**openzeppelin-contracts/contracts/token/ERC20/ERC20.sol**

```solidity
function _transfer(address from, address to, uint256 value) internal {
        **if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }**
        **if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }**
        _update(from, to, value);
    }
```

**solmate/src/tokens/ERC20.sol**

```solidity
function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }
```