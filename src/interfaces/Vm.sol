// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//virtual machine
interface Vm {
    function expectRevert(bytes calldata) external;

    function prank(address) external;

    function load(address c, bytes32 loc) external returns (bytes32);

    function warp(uint256) external;
}