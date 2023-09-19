// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract CurveGateway {
    address public PoolDAI_USDC_USDT; // Address of the DAI Curve pool contract
    address public uniswapRouter; // Address of Uniswap V2 Router contract
    address public Treasury; 
    mapping(address => uint256) public userATokenBalances;
    uint256 public indexTokens;
    uint256 private indexProtocle; 
   address DAIaddress;

    constructor(address _PoolDAI_USDC_USDT, address _uniswapRouter,address _DAIaddress,address _treasury) {
        PoolDAI_USDC_USDT = _PoolDAI_USDC_USDT;
        uniswapRouter = _uniswapRouter;
        DAIaddress = _DAIaddress;
        Treasury = _treasury;
    }

    // Function to deposit tokens into the DAI Curve pool after swapping with Uniswap V2
    function deposit(
        address tokenInAddress
    ) public  {
         require(msg.sender == Treasury , "only from treasury");

        uint256 amount = IERC20(tokenInAddress).balanceOf(address(this));
        IERC20(tokenInAddress).approve(uniswapRouter, amount);
        uint256 amountToDeposit = amount;
        if(tokenInAddress != DAIaddress)
        {
            userATokenBalances[tokenInAddress] +=amount;
        // Swap tokens using Uniswap V2 to DAI
        address[] memory path = new address[](2);
        path[0] = tokenInAddress;
        path[1] = DAIaddress;
        uint[] memory amounts = IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
            amount,
            0, // Accept any amount of output tokens
            path,
            address(this),
            block.timestamp
        );
        amountToDeposit = amounts[1];
        }
        // Deposit the swapped DAI tokens into the DAI Curve pool
        require(ICurvePool(PoolDAI_USDC_USDT).add_liquidity([amountToDeposit,0,0], 0) > 0, "Deposit failed");
    }

    // Function to withdraw DAI tokens from the DAI Curve pool
    function withdrawDai(address tokenINAddress , uint256 amount) public  {
        require(msg.sender == Treasury , "only from treasury");
        // Withdraw DAI tokens from the DAI Curve pool
        uint256 amountToSend = amount;
        require(amount <= userATokenBalances[tokenINAddress] ,"exceed the deposits");
        
        ICurvePool(PoolDAI_USDC_USDT).remove_liquidity_one_coin(amount, 0, 0);

        if (tokenINAddress != DAIaddress)
        {
            userATokenBalances[tokenINAddress] -=amount;
            address[] memory path = new address[](2);
            path[0] = DAIaddress;
            path[1] = tokenINAddress; 
            uint[] memory amounts = IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
            amount,
            0, // Accept any amount of output tokens
            path,
            address(this),
            block.timestamp
        );
        amountToSend = amounts[1];
                
        }
        IERC20(address(tokenINAddress)).transfer(Treasury, amountToSend); // Replace with the correct DAI address
    }

  
}

interface ICurvePool {
    function add_liquidity(uint256[3] calldata amounts, uint256 min_mint_amount) external returns (uint256);
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256);
}