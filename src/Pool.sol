// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/Configuration.sol";
import "./interfaces/Vault.sol";

contract Pool is Ownable(msg.sender) {
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

    function supply(address tokenAddress, uint256 amount) public {

      require(tokenAddress != DEAD_ADDRESS, "You cannot provide a burn address");
      require(tokenAddress != address(0), "You cannot provide a burn address");

      if (_config.isSupported(tokenAddress)) {

        IERC20 assetContract = IERC20(tokenAddress);
        assetContract.transferFrom(msg.sender,address(this),amount);

        // no unlimted allowance to Slast. Only give allowances as needed
        assetContract.approve(address(_vaultAddress), amount);
        _vaultAddress.deposit(tokenAddress,amount,address(this),0);
      }

      userHoldings[msg.sender][tokenAddress] += amount;

      emit Deposit(msg.sender,tokenAddress,amount);
    }

    function depositNativeToken() public payable {

      _wethGateway.depositETH{value:msg.value}(address(_vaultAddress),address(this), 0);

      userHoldings[msg.sender][DEAD_ADDRESS] += msg.value;

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
