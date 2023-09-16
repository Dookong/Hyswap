//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Exchange.sol";

contract Factory{
    event NewExchange(address indexed token, address indexed exchange);

    mapping(address => address) tokenToExchange;

    function createExchange(address _token) public returns (address) {
        require(_token != address(0));
        require(tokenToExchange[_token] != address(0));
        Exchange exchange = new Exchange(_token);
        tokenToExchange[_token] = address(exchange);

        emit NewExchange(_token, address(exchange));
        return address(exchange);
    }

    function getExchange(address _token) public view returns (address) {
        return tokenToExchange[_token];
    }
}
