//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IExchange.sol";

contract Exchange is ERC20{
    // Events
    event TokenPurchase(address indexed buyer, uint256 indexed eth_sold, uint256 indexed tokens_bought);
    event EthPurchase(address indexed buyer, uint256 indexed tokens_sold, uint256 indexed eth_bought);
    event AddLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);
    event RemoveLiquidity(address indexed provider, uint256 indexed eth_amount, uint256 indexed token_amount);

    IERC20 token;
    IFactory factory;

    constructor (address _token) ERC20("GRAY UNISWAP V2", "GUNI") {
        token = IERC20(_token);
        factory = IFactory(msg.sender);
    }

    function addLiquidity(uint256 maxTokens) public payable {
        uint totalLiquidity = totalSupply();
        if (totalLiquidity > 0) {
            uint etherReserve = address(this).balance - msg.value;
            uint tokenReserve = token.balanceOf(address(this));
            uint tokenAmount = msg.value * tokenReserve / etherReserve;

            require(maxTokens >= tokenAmount);

            token.transferFrom(msg.sender, address(this), tokenAmount);
            uint liquidityMinted = totalLiquidity * msg.value / etherReserve;
            _mint(msg.sender, liquidityMinted);
        } else {
            uint tokenAmount = maxTokens;
            uint initialLiquidity = address(this).balance;
            _mint(msg.sender, initialLiquidity); 
            token.transferFrom(msg.sender, address(this), tokenAmount);
        }
    }

    function removeLiquidity(uint lpTokenAmount) public {
        require(lpTokenAmount > 0);
        uint ethAmount = lpTokenAmount * address(this).balance / totalSupply();
        uint tokenAmount = lpTokenAmount * token.balanceOf(address(this)) / totalSupply();

        _burn(msg.sender, lpTokenAmount);

        payable(msg.sender).transfer(ethAmount);
        token.transfer(msg.sender, tokenAmount);

    }

    // ETH -> ERC20
    function ethToTokenSwap(uint minTokens) public payable {
        ethToToken(minTokens, msg.sender);
    }

    function ethToTokenTransfer(uint minTokens, address receipent) public payable {
        ethToToken(minTokens, receipent);
    }

    function ethToToken(uint minTokens, address receipent) private{
        require(receipent != address(0));
        uint256 outputAmount = getOutputAmount(msg.value, address(this).balance - msg.value, token.balanceOf(address(this)));
        require(outputAmount >= minTokens, "Insufficient ouputAmount!");
        IERC20(token).transfer(receipent, outputAmount);
    }

    // ERC20 -> ETH
    function tokenToEthSwap(uint tokenSold, uint minEth) public payable {
        uint256 outputAmount = getOutputAmount(tokenSold, token.balanceOf(address(this)), address(this).balance);
        require(outputAmount >= minEth, "Insufficient ouputAmount!");

        IERC20(token).transferFrom(msg.sender, address(this), tokenSold);
        payable(msg.sender).transfer(outputAmount);
    }

    // ERC20 -> ERC20
    function tokenToTokenSwap(uint tokenSold, uint minTokenBought, uint minEthBought, address _tokenAddress) public payable {
        address toTokenExchangeAddress = factory.getExchange(_tokenAddress);

        
        uint256 ethOutputAmount = getOutputAmount(tokenSold, token.balanceOf(address(this)), address(this).balance);
        require(ethOutputAmount >= minEthBought, "Insufficient ouputAmount!");

        IERC20(token).transferFrom(msg.sender, address(this), tokenSold);

        //인터페이스 정의
        IExchange(toTokenExchangeAddress).ethToTokenTransfer{value: ethOutputAmount}(minTokenBought, msg.sender);
    }

    function getPrice(uint256 inputReserve, uint256 outputReserve) public pure returns (uint){
        uint256 numerator = inputReserve;
        uint256 denominator = outputReserve;
        return numerator / denominator;
    }

    function getOutputAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint){
        uint256 numerator = outputReserve * inputAmount;
        uint256 denominator = inputReserve + inputAmount;
        return numerator / denominator;
    }

    function getOutputAmountWithFee(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint){
        uint inputAmountWithFee = inputAmount * 99;
        uint256 numerator = outputReserve * inputAmountWithFee;
        uint256 denominator = inputReserve * 100 + inputAmount;
        return numerator / denominator;
    }
}

