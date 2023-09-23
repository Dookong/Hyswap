//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./interfaces/IPairExchange.sol";
import "./PairExchange.sol";

contract Factory{
    event PairCreated(address indexed token0, address indexed token1, address pair);

    mapping(address => mapping(address => address)) tokenPair;

    address public feeAddress; // the destination address of trading fees
    address public feeAddressSetter; // the address that can change the feeAddress

    address[] public allExchanges;

    constructor(address _feeAddressSetter) {
        feeAddressSetter = _feeAddressSetter;
    }

    function createTokenPair(address _token1, address _token2) public returns (address pair) {
        require(_token1 != address(0));
        require(_token2 != address(0));
        require(_token1 != _token2);
        (address token1, address token2) = _token1 < _token2 ? (_token1, _token2) : (_token2, _token1);
        require(tokenPair[token1][token2] == address(0)); // pool이 이미 존재하는지 확인

        bytes memory contractByteCode = type(PairExchange).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token1, token2));  
        assembly {
            pair := create2(0, add(contractByteCode, 32), mload(contractByteCode), salt)
        }
        pair = address(new PairExchange(token1, token2));// 제대로 작동할지 모르겠음.
        tokenPair[token1][token2] = pair;
        tokenPair[token1][token2] = pair;
        emit PairCreated(token1, token2, pair);
    }

    function setFeeAddress(address _feeAddress) external {
        require(msg.sender == feeAddressSetter, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    function setFeeAddressSetter(address _feeAddressSetter) external {
        require(msg.sender == feeAddressSetter, "setFeeAddressSetter: FORBIDDEN");
        feeAddressSetter = _feeAddressSetter;
    }    
}
