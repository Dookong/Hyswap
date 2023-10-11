pragma solidity ^0.8.13;

import "../interfaces/IFactory.sol";
import "./HySwapPair.sol";

error IDENTICAL_ADDRESSES();
error ZERO_ADDRESS();
error PAIR_EXISTS();

contract Factory is IFactory {


    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair){
        if(tokenA == tokenB) revert IDENTICAL_ADDRESSES();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if(token0 == address(0) || token1 == address(0)) revert ZERO_ADDRESS();
        if(getPair[token0][token1] != address(0)) revert PAIR_EXISTS(); // single check is sufficient

        bytes memory bytecode = type(HySwapPair).creationCode;

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IHySwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external{
        require(msg.sender == feeToSetter, 'HySwap: FORBIDDEN');
        feeTo = _feeTo;
    }
    function setFeeToSetter(address _feeToSetter) external{
        require(msg.sender == feeToSetter, 'HySwap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}