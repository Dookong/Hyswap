// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function balanceOf(address) external returns (uint);
    function transfer(address to, uint amount) external;
}