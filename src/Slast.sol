// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/Configuration.sol";
import "./interfaces/Vault.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

event Deposit(address indexed from, address indexed token, uint256 amount);
event Withdraw(address indexed from, address indexed token, uint256 amount);
event Forward(address indexed from, address indexed recipient, address indexed token, uint256 amount);

contract Slast is Initializable, UUPSUpgradeable , OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable{

    using Math for uint256;

    // Slast's fee
    uint256 private feePercentage;

    struct HoldingsInfo {
        uint256 amount;
    }

    mapping(address => HoldingsInfo) private balanceMappings;

    struct SavingsConfig {
      uint256 percentage;

      bool pauseSave;
    }

    mapping(address => SavingsConfig) private userSavingsConfig;

    uint256 private defaultPercentage;

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

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {
    } 

    function initialize(uint256 _feePercentage, address _aavePool, address _configuration,address _nativeGateway) initializer public {

      __UUPSUpgradeable_init();
      __Ownable_init(msg.sender);
      __ReentrancyGuard_init();
      __Pausable_init();

      require(address(_aavePool) != address(0), "Aave pool vault cannot be a zero address"); 
      require(address(_configuration) != address(0), "Configurator address cannot be a zero address"); 
      require(address(_nativeGateway) != address(0), "WETH gateway address cannot be a zero address"); 

      feePercentage = _feePercentage;
      defaultPercentage = 1 * 100;  // 1% is expressed as 100
      _vaultAddress = Vault(_aavePool);
      _config = Configuration(_configuration);
      _wethGateway = NativeVault(_nativeGateway);
    }

    function pause() public onlyOwner {
      _pause();
    }

    function unpause() public onlyOwner {
      _unpause();
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

    function calculatePercentage(uint256 amount, uint256 percentage) private pure returns (uint256) {
      return Math.mulDiv(amount, percentage, 10000);
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

    function getSavingsConfig() external view returns (uint256 percentage, bool isPaused) {

      SavingsConfig memory config = userSavingsConfig[msg.sender];

      if (config.percentage == 0) {
        return (defaultPercentage/100,false);
      }

      return (config.percentage/100, config.pauseSave); 
    }

    function updateUserSavingsConfig(
      uint256 newPercentage, 
      bool shouldPauseSavings
    ) public {

      require(newPercentage > 0, "your savings percentage rate must be more than 0");
      require(newPercentage <= 50, "your savings percentage rate can only be a maximum of 50%");

      userSavingsConfig[msg.sender].percentage = newPercentage * 100;
      userSavingsConfig[msg.sender].pauseSave = shouldPauseSavings;
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

    function withdrawNativeToken(uint256 amount) public nonReentrant {

      address tokenAddress = DEAD_ADDRESS;

      require(amount != 0, "You cannot withdraw zero tokens");

      require(userHoldings[msg.sender][tokenAddress] > 0, "You do not hold this token so cannot withdraw");

      require(userHoldings[msg.sender][tokenAddress] >= amount, "You do not hold enough tokens");

      userHoldings[msg.sender][tokenAddress] = safeSub(userHoldings[msg.sender][tokenAddress], amount);

      require(userHoldings[msg.sender][tokenAddress] >= 0, "Your balance is off");

      // send directly to the user;
      _wethGateway.withdrawETH(tokenAddress,amount,msg.sender);

      emit Withdraw(msg.sender,tokenAddress,amount);
    }

    function supply(address tokenAddress, uint256 amount) public whenNotPaused {

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

    function saveAndSpendToken(address tokenAddress, uint256 amount, address receiver) public whenNotPaused {

      require(tokenAddress != DEAD_ADDRESS, "You cannot provide a burn address");
      require(tokenAddress != address(0), "You cannot provide a burn address");

      uint256 perc = userSavingsConfig[msg.sender].percentage;

      if (perc == 0) {
        perc = defaultPercentage;
      }

     uint256 discountedPrice = calculatePercentage(amount, perc);

     uint256 amountToTransfer = amount - discountedPrice;

     // transfer the new amount to the intended recipient
     IERC20 assetContract = IERC20(tokenAddress);
     assetContract.transferFrom(msg.sender,receiver, amountToTransfer);

     supply(tokenAddress, discountedPrice);

     emit Forward(address(msg.sender), receiver, tokenAddress, amountToTransfer);
    }

    function depositNativeToken() public payable whenNotPaused {

      userHoldings[msg.sender][DEAD_ADDRESS] = safeAdd(userHoldings[msg.sender][DEAD_ADDRESS],msg.value);

      _wethGateway.depositETH{value:msg.value}(address(_vaultAddress),address(this), 0);

      emit Deposit(msg.sender,DEAD_ADDRESS,msg.value);
    }
}
