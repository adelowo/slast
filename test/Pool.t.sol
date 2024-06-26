// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.23;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Test,console} from "forge-std/Test.sol";
import "../src/Slast.sol";
import "../src/Config.sol";
import "../src/interfaces/Vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface Token {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external; // Add mint function
}

contract MockLendingPool is Vault {
    mapping(address => uint256) public deposits;

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        deposits[onBehalfOf] += amount;
    }

    function depositETH(address, address onBehalfOf, uint16 referralCode) external payable {
        deposits[onBehalfOf] += msg.value;
    }

  function withdraw(address asset, uint256 amount, address to) external {
    deposits[msg.sender] -= amount;
  }

  function withdrawETH(address asset, uint256 amount, address to) external {
    deposits[msg.sender] -= amount;
  }
}

contract MockToken is ERC20{

    constructor (string memory _name, string memory _symbol) ERC20 (_name,_symbol){
    }

    function mint(address to, uint256 amount) public virtual {
        _mint(to,amount);
    }

    function burn(address form, uint amount) public virtual {
        _burn(form, amount);
    }
}


contract PoolTest is Test {

  Slast poolContract;
  MockToken public testToken;
  Config cfg;
  Vault mockLendingPool;

  uint256 percentage = 1;

  address private constant usdcContractAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  function setUp() public {

    cfg = new Config();
    mockLendingPool = new MockLendingPool();

    poolContract = new Slast();

    poolContract.initialize(percentage, address(mockLendingPool), address(cfg),address(mockLendingPool));

    testToken = new MockToken("USDC", "USDC");

    cfg.addSupportedAsset(address(testToken));
  }

  function test_getFee() public {
    assertEq(poolContract.getFee(),percentage);
  }

  function test_depositNativeToken() public {
    uint256 depositAmount = 0.1 ether;
    address testAddress = address(0x123); 

    vm.deal(testAddress, depositAmount); 

    vm.startPrank(testAddress); 

    poolContract.depositNativeToken{value: depositAmount}();

    assertEq(poolContract.getNativeTokenBalance(),depositAmount);

    vm.stopPrank(); 
  }

  function test_withdraw_native_token() public {


    address testAddress = address(0x126); 
    uint256 depositAmount = 0.1 ether;

    vm.deal(testAddress, depositAmount); 

    vm.startPrank(testAddress); 

    poolContract.depositNativeToken{value: depositAmount}();


    // right token, zero amount
    vm.expectRevert(bytes("You cannot withdraw zero tokens"));
    poolContract.withdrawNativeToken(0);

    // right token but not enough balance
    vm.expectRevert(bytes("You do not hold enough tokens"));
    poolContract.withdrawNativeToken(0.2 ether); // we supplied 0.1 ether


    vm.expectEmit(true,true,true,true,address(poolContract));
    emit Withdraw(address(testAddress),  0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, depositAmount);

    // check balance before withdrawal
    assertEq(poolContract.getNativeTokenBalance(),depositAmount);
    poolContract.withdrawNativeToken(depositAmount);

    // make sure all was taken off
    assertEq(poolContract.getNativeTokenBalance(), 0);

    vm.stopPrank(); 
  }

  function test_withdraw() public {


    address testAddress = address(0x126); 

    uint256 amountToSupply = 50 * (10 ** testToken.decimals());
    testToken.mint(testAddress, amountToSupply);

    vm.startPrank(testAddress); 

    testToken.approve(address(poolContract), amountToSupply);


    poolContract.supply(address(testToken),amountToSupply);


    // cannot withdraw a zero address token
    vm.expectRevert(bytes("You cannot provide a burn address"));
    poolContract.withdraw(address(0),amountToSupply);

    // cannot withdraw DEAD address token
    vm.expectRevert(bytes("You cannot provide a burn address"));
    poolContract.withdraw(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,amountToSupply);

    // right token, zero amount
    vm.expectRevert(bytes("You cannot withdraw zero tokens"));
    poolContract.withdraw(usdcContractAddress,0);

    // cannot withdraw token user is not holding
    vm.expectRevert(bytes("You do not hold this token so cannot withdraw"));
    poolContract.withdraw(address(0x130),amountToSupply);

    // right token but not enough balance
    vm.expectRevert(bytes("You do not hold enough tokens"));
    poolContract.withdraw(address(testToken),amountToSupply * 2);


    vm.expectEmit(true,true,true,true,address(poolContract));
    emit Withdraw(address(testAddress), address(testToken), amountToSupply);

    // check balance before withdrawal
    assertEq(poolContract.balanceOf(address(testToken)), amountToSupply);

    poolContract.withdraw(address(testToken),amountToSupply);

    // make sure all was taken off
    assertEq(poolContract.balanceOf(address(testToken)), 0);

    vm.stopPrank(); 
  }

  function test_getSavingsConfig() public {

    address testAddress = address(0x126); 

    vm.startPrank(testAddress);

    (uint256 percentage,bool isPaused) = poolContract.getSavingsConfig();

    assertEq(percentage, 1);
    assertFalse(isPaused);

    poolContract.updateUserSavingsConfig(50,true);

    (uint256 newpercentage,bool newisPaused) = poolContract.getSavingsConfig();

    assertEq(newpercentage, 50);
    assertTrue(newisPaused);

    vm.stopPrank();
  }

  function test_updateUserSavingsConfig() public {

    address testAddress = address(0x126); 

    vm.expectRevert(bytes("your savings percentage rate must be more than 0"));
    poolContract.updateUserSavingsConfig(0,true);


    vm.expectRevert(bytes("your savings percentage rate can only be a maximum of 50%"));
    poolContract.updateUserSavingsConfig(51,true);

    poolContract.updateUserSavingsConfig(50,true);
  }


  function test_forwardToken_with_user_savings_config() public {

    address testAddress = address(0x126); 
    address recipientAddress = address(0x166);

    uint256 amountToSupply = 50 * (10 ** testToken.decimals());

    testToken.mint(testAddress, amountToSupply);

    vm.startPrank(testAddress); 

    // take 50%
    uint256 expectedAmountToSave = Math.mulDiv(amountToSupply, 50 * 100, 10000);

    poolContract.updateUserSavingsConfig(50,true);

    testToken.approve(address(poolContract), amountToSupply);

    poolContract.saveAndSpendToken(address(testToken), amountToSupply, recipientAddress);

    assertEq(poolContract.balanceOf(address(testToken)), expectedAmountToSave);
    vm.stopPrank(); 

    // make sure recipientAddress got the expected amount
    assertEq(testToken.balanceOf(recipientAddress),amountToSupply - expectedAmountToSave);

    // make sure pool contract got the right amount
    assertEq(testToken.balanceOf(address(poolContract)), expectedAmountToSave);
  }


  function test_forwardToken_default_savings_config() public {

    address testAddress = address(0x126); 
    address recipientAddress = address(0x166);

    uint256 amountToSupply = 50 * (10 ** testToken.decimals());
    // 1% is the default
    uint256 expectedAmountToSave = Math.mulDiv(amountToSupply, 1 * 100, 10000);

    testToken.mint(testAddress, amountToSupply);

    vm.startPrank(testAddress); 

    testToken.approve(address(poolContract), amountToSupply);

    vm.expectEmit(true,true,true,true,address(poolContract));
    emit Forward(address(testAddress),  recipientAddress,address(testToken), amountToSupply - expectedAmountToSave);

    poolContract.saveAndSpendToken(address(testToken), amountToSupply, recipientAddress);

    assertEq(poolContract.balanceOf(address(testToken)), expectedAmountToSave);
    vm.stopPrank(); 

    // make sure recipientAddress got the expected amount
    assertEq(testToken.balanceOf(recipientAddress),amountToSupply - expectedAmountToSave);

    // make sure pool contract got the right amount
    assertEq(testToken.balanceOf(address(poolContract)), expectedAmountToSave);
  }

  function test_supply() public {

    address testAddress = address(0x126); 

    uint256 amountToSupply = 50 * (10 ** testToken.decimals());
    testToken.mint(testAddress, amountToSupply);

    vm.startPrank(testAddress); 

    testToken.approve(address(poolContract), amountToSupply);


    poolContract.supply(address(testToken),amountToSupply);

    assertEq(poolContract.balanceOf(address(testToken)), amountToSupply);
    vm.stopPrank(); 

    // since we have drawn everything off
    assertEq(testToken.balanceOf(testAddress),0);

    // make sure the contract has the correct and expected amount
    assertEq(testToken.balanceOf(address(poolContract)),amountToSupply);
  }

  // this should not supply to Aave but the balance of the token should go up too
  function test_supply_non_supported_asset() public {

    address testAddress = address(0x126); 

    MockToken tt = new MockToken("TestUSDC", "USDC");

    uint256 amountToSupply = 50 * (10 ** testToken.decimals());
    tt.mint(testAddress, amountToSupply);

    vm.startPrank(testAddress); 

    tt.approve(address(poolContract), amountToSupply);

    poolContract.supply(address(tt),amountToSupply);

    assertEq(poolContract.balanceOf(address(tt)), amountToSupply);
    vm.stopPrank(); 

    // since we have drawn everything off
    assertEq(tt.balanceOf(testAddress),0);

    // make sure the contract has the correct and expected amount
    assertEq(tt.balanceOf(address(poolContract)),amountToSupply);
  }

  function test_supply_zero_address() public {

    vm.expectRevert();

    poolContract.supply(address(0),5000);

    vm.expectRevert();

    poolContract.supply(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,5000);
  }

  function test_constructor_no_zero_address() public {


    address testAddress = address(0x126); 

    Slast p = new Slast();

    vm.expectRevert();
    p.initialize(0,address(0),testAddress,testAddress);

    p = new Slast();
    vm.expectRevert();
    p.initialize(0,testAddress, address(0),testAddress);

    p = new Slast();
    vm.expectRevert();
    p.initialize(0,testAddress, testAddress,address(0));
  }
}
