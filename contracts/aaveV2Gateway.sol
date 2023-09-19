// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the Aave V2 lending pool and ERC20 interfaces
import "./utils/ILendingPool.sol";
import "./Treasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveV2Gateway {
    // Address of the Aave V2 LendingPool contract
    address public lendingPoolAddress;
    
    // Address of the Treasury contract
    address public treasuryAddress;
    
    // Mapping to store user aTokens balances
    mapping(address => uint256) public userATokenBalances;
    mapping(address => address) public TokensATokens;
    uint256 public indexTokens;
    uint256 private indexProtocle; 
    
    constructor(address _lendingPoolAddress, address _treasuryAddress,uint256 _indexProtocle) {
        lendingPoolAddress = _lendingPoolAddress;
        treasuryAddress = _treasuryAddress;
        indexProtocle = _indexProtocle;
    }
    
    // Deposit tokens from the treasury into Aave V2 and receive aTokens
    function deposit(address _tokenAddress) external {
        require(msg.sender == treasuryAddress, "Only the treasury can deposit");
        
        // Approve Aave V2 LendingPool to spend the tokens
        IERC20 token = IERC20(_tokenAddress);
        uint256 _amount = token.balanceOf(address(this));
        token.approve(lendingPoolAddress, _amount);
        
        // Deposit tokens into Aave V2 and receive aTokens
        ILendingPool lendingPool = ILendingPool(lendingPoolAddress);
        lendingPool.deposit(_tokenAddress, _amount, address(this), 0);
        address aTokenAddress = lendingPool.getReserveData(_tokenAddress).aTokenAddress;

        // Update user's aToken balance
        userATokenBalances[aTokenAddress] += _amount;
        TokensATokens[_tokenAddress] =aTokenAddress;
        indexTokens++;
    }
    
    // Withdraw an amount of aTokens and send the corresponding tokens to the user
    function withdraw(address Token, uint256 _aTokenAmount) external {
        require(msg.sender == treasuryAddress, "Only the treasury can deposit");

        address aTokenAddress = TokensATokens[Token];
        require(aTokenAddress != address(0),"aToken not Found");
        require(userATokenBalances[aTokenAddress] > 0,"no Atoken to withdraw");
        require(userATokenBalances[aTokenAddress] >= _aTokenAmount, "Insufficient aTokens balance");
        
        // Withdraw aTokens from Aave V2 and receive the corresponding tokens
        ILendingPool lendingPool = ILendingPool(lendingPoolAddress);
        lendingPool.withdraw(aTokenAddress, _aTokenAmount, treasuryAddress);
        
        // Update user's aToken balance
        userATokenBalances[aTokenAddress] -= _aTokenAmount;
    }
    function calculateYields() external view returns (uint256) {
        address[] memory tokens = Treasury(treasuryAddress).getTokensList();
        uint256 totalInterest = 0;

        for (uint256 i = 0; i < tokens.length ; i++) {
            totalInterest += calculateAssetYield(tokens[i]);
        }

        return totalInterest;
    }
    function calculateAssetYield(address _tokenAddress) internal view returns (uint256) {
        ILendingPool lendingPool = ILendingPool(lendingPoolAddress);
        uint256 depositedAmount = Treasury(treasuryAddress).getDepositTokens(_tokenAddress,indexProtocle);
        uint256 currentLiquidityRate = lendingPool.getReserveData(_tokenAddress).currentLiquidityRate;
        uint256 yield = (depositedAmount * currentLiquidityRate) / 1e18; // Assuming currentLiquidityRate is in Aave's format (18 decimal places)

       
        return yield;
    }
}
