// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/Configuration.sol";
import "./interfaces/Vault.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract Pool is Ownable(msg.sender), ReentrancyGuard {

    using Math for uint256;

    uint256 public feePercentage;

    struct HoldingsInfo {
        uint256 amount;
    }

    mapping(address => HoldingsInfo) private balanceMappings;

    // We use this as a token address to identiy ETH native token
    // we don't send anything to the burn address EVER
    address private constant DEAD_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // user balance ==> toekn address ==> balance
    // 0x000000000000000000000000000000000000dEaD will be used for ETH
    mapping(address => mapping(address => uint256)) private userHoldings;

    // we eventually want to support more than the Base chain
    // at some time in the future. so no need to hardcode
    Vault _vaultAddress;

    NativeVault _wethGateway;

    Configuration _config;

    event Deposit(address indexed from, address indexed token, uint256 amount);
    event Withdraw(address indexed from, address indexed token, uint256 amount);

    constructor(uint256 _feePercentage, address _aavePool, 
                address _configuration,
                address _nativeGateway) {

      require(address(_aavePool) != address(0), "Aave pool vault cannot be a zero address"); 
      require(address(_configuration) != address(0), "Configurator address cannot be a zero address"); 
      require(address(_nativeGateway) != address(0), "WETH gateway address cannot be a zero address"); 

      feePercentage = _feePercentage;
      _vaultAddress = Vault(_aavePool);
      _config = Configuration(_configuration);
      _wethGateway = NativeVault(_nativeGateway);
    }

    function safeAdd(uint256 a, uint256 b) private pure returns (uint256) {
      (bool noOverflow, uint256 c) = Math.tryAdd(a,b);
      require(noOverflow, "Overflow from addition");
      return c;
    }

    function safeSub(uint256 a, uint256 b) private pure returns (uint256) {
      (bool noOverflow, uint256 c) = Math.trySub(a, b);
      require(noOverflow, "Overflow from subtraction");
      return c;
    }

    function withdraw(address tokenAddress, uint256 amount) public nonReentrant {

      require(tokenAddress != DEAD_ADDRESS, "You cannot provide a burn address");
      require(tokenAddress != address(0), "You cannot provide a burn address");
      require(amount != 0, "You cannot withdraw zero tokens");

      require(userHoldings[msg.sender][tokenAddress] > 0, "You do not hold this token so cannot withdraw");

      require(userHoldings[msg.sender][tokenAddress] >= amount, "You do not hold enough tokens");

      userHoldings[msg.sender][tokenAddress] = safeSub(userHoldings[msg.sender][tokenAddress], amount);

      require(userHoldings[msg.sender][tokenAddress] >= 0, "Your balance is off");

      // send directly to the user;
      _vaultAddress.withdraw(tokenAddress,amount,msg.sender);

      emit Withdraw(msg.sender,tokenAddress,amount);
    }

    function supply(address tokenAddress, uint256 amount) public {

      require(tokenAddress != DEAD_ADDRESS, "You cannot provide a burn address");
      require(tokenAddress != address(0), "You cannot provide a burn address");


      uint256 balance = userHoldings[msg.sender][tokenAddress];

      userHoldings[msg.sender][tokenAddress] = safeAdd(balance,amount);

      if (_config.isSupported(tokenAddress)) {

        IERC20 assetContract = IERC20(tokenAddress);
        assetContract.transferFrom(msg.sender,address(this),amount);

        // no unlimted allowance to Slast. Only give allowances as needed
        assetContract.approve(address(_vaultAddress), amount);
        _vaultAddress.deposit(tokenAddress,amount,address(this),0);
      }

      emit Deposit(msg.sender,tokenAddress,amount);
    }

    function depositNativeToken() public payable {

      userHoldings[msg.sender][DEAD_ADDRESS] = safeAdd(userHoldings[msg.sender][DEAD_ADDRESS],msg.value);

      _wethGateway.depositETH{value:msg.value}(address(_vaultAddress),address(this), 0);

      emit Deposit(msg.sender,DEAD_ADDRESS,msg.value);
    }

    function getFee() external view returns (uint256) {
      return feePercentage;
    }

    function balanceOf(address tokenAddress) public view returns (uint256) {
      return userHoldings[msg.sender][tokenAddress];
    }

    function getNativeTokenBalance() public view returns (uint256)  {
      return balanceOf(DEAD_ADDRESS);
    }
}
