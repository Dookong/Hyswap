 /* 
    Q notation = 이진 고정 소수점 숫자를 포맷하는 방법
    Q8.8 => 정수부 8비트 + 소수부 8비트
    UQ = Unsigned Q: 음수 없는 대신 (2배-1)만큼 더 넓은 범위 표현 가능
    UQ112.112 => 정수부 112비트 + 소수부 112비트로 구성된 0 또는 양수
    왜 하필 112라는 숫자를 쓰는가? 112 + 112 + 32 = 256!
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

library UQ112x112{
    // uint224를 uq112.112로 나눠서 사용
    // 왜? uint256보다 메모리 아낄 수 있음
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}