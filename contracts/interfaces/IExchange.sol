//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface IExchange {
    function ethToTokenTransfer(uint minTokens, address receipent) external payable;
}