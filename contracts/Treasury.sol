// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the ERC-20 interface for the token
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IProtocolDEFI {
    function deposit(address _tokenAddress) external;
    function withdraw(address Token, uint256 _aTokenAmount) external;
}
contract Treasury {
    address public owner;
    bool public locked;
    enum ProtocolType {
        LiquidityPool,
        DeFiProtocol
    }
    // Struct to track user deposits
    struct DepositUser {
        uint256 depositAmount;
        uint256 lastDeposit;
    }
   //The admin can add any protocol by praparing the gateway , this solution will be scalable to add any invest protocol
    struct Protocol {
        ProtocolType Type;
        address Gateway;
        string ProtocolName; 
    }
     

    mapping(address => uint256) public userDepositIndexs;
    mapping(address => mapping(address => DepositUser)) public userDeposits;
    //the protocol will be saved on this map
    mapping(uint => Protocol) public ProtocolsInvestment;
    mapping(address => mapping(uint => uint256)) public Invests;
    mapping(uint256 => address) private TokensO;
    uint256 private protocolsIndex;
    uint256 public protocolRatio;
    uint256 private indexTokensU;
    // Initialize the contract with the owner
    constructor(uint256 initialRatio) {
        owner = msg.sender;
        protocolRatio= initialRatio;
    }
    modifier noReentrancy() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // Deposit funds into the Treasury for a specific token
    function deposit(address _tokenAddress, uint256 _amount) external noReentrancy{
        require(_amount > 0, "Amount must be greater than 0");
        
        // Transfer tokens from the user to the contract
        IERC20 token = IERC20(_tokenAddress);
        token.transferFrom(msg.sender, address(this), _amount);
        
        // Update the user's deposit information
        
        userDeposits[msg.sender][_tokenAddress] = DepositUser(_amount,block.timestamp);
        userDepositIndexs[msg.sender]++;
        TokensO[indexTokensU] = _tokenAddress;
        indexTokensU++;
    }
    
    // Function to allow users to withdraw their allocated funds for a specific token
    function withdraw(address _tokenAddress, uint256 _amount) external noReentrancy{
        require(_amount > 0, "Amount must be greater than 0");
        
        DepositUser storage userDeposit = userDeposits[msg.sender][_tokenAddress];
        
        require(userDeposit.depositAmount >= _amount, "Exceeds deposited amount");
        
        // Implement interaction to withdraw funds here
        // Example: protocolContract.withdraw(_tokenAddress, _amount);
        
        // Update the user's withdrawn amount
        userDeposit.depositAmount -= _amount;
        if (userDeposit.depositAmount == 0)
        {
            userDepositIndexs[msg.sender] = userDepositIndexs[msg.sender] -1 ;
        }
    }
    function adjustRatio(uint256 _protocolRatio) external {
        require(msg.sender == owner, "Only the owner can adjust ratios");
        require(_protocolRatio <= 100, "Ratio cannot exceed 100%");
        protocolRatio = _protocolRatio;
    }
    function AddingProtocol(Protocol calldata _protocol) external {
        require(msg.sender == owner, "Only the owner can adjust ratios");
        ProtocolsInvestment[protocolsIndex] = _protocol;
        protocolsIndex++;
    }
    // Function to distribute funds to DeFi protocols and retain in the treasury based on ratio
    function allocateFundsInvest(address _tokenAddress,uint256 indexProtocol) external noReentrancy{
        require(msg.sender == owner, "Only the owner can allocate funds");
        uint256 tokenBalance = IERC20(_tokenAddress).balanceOf(address(this));
        uint256 protocolAmount = (tokenBalance * protocolRatio) / 100;
        address GatewayAddress = ProtocolsInvestment[indexProtocol].Gateway;
        // Transfer the remaining amount to the owner (treasury)
        IERC20(_tokenAddress).transfer(GatewayAddress, protocolAmount);
         if(ProtocolsInvestment[indexProtocol].Type == ProtocolType.DeFiProtocol)
        {
        IProtocolDEFI(GatewayAddress).deposit(_tokenAddress);
        }
        Invests[_tokenAddress][indexProtocol] += protocolAmount;

    }
    function WithdrawFromProtocol(address _tokenAddress,uint256 amount,uint256 indexProtocol) external noReentrancy{
        require(msg.sender == owner, "Only the owner can allocate funds");
        address GatewayAddress = ProtocolsInvestment[indexProtocol].Gateway;
        // Transfer the remaining amount to the owner (treasury)
        if(ProtocolsInvestment[indexProtocol].Type == ProtocolType.DeFiProtocol)
        {
        IProtocolDEFI(GatewayAddress).withdraw(_tokenAddress,amount);
        }
        Invests[_tokenAddress][indexProtocol] -= amount;
    }
     function getDepositTokens(address _tokenAddress,uint256 indexProtocol) external view returns (uint256) {
       
        return Invests[_tokenAddress][indexProtocol];
    }
    function getTokensList() external view returns (address[] memory) {
        address[] memory tokens = new address[](indexTokensU);
        
        for (uint256 i = 0; i < indexTokensU ; i++) {
            tokens[i] = TokensO[i]; 
        }

        return tokens;
            }
    

}
