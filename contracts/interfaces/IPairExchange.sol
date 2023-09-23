pragma solidity ^0.8.9;

interface IPairExchange {
    function addLiquidity(uint256 maxTokens) external payable;
    function removeLiquidity(uint lpTokenAmount) external;
    function swap() external;
    function mint() external;
    function burn() external;
}