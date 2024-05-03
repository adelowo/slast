// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.23;

import {Test,console} from "forge-std/Test.sol";
import "../src/Pool.sol";
import "../src/Config.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "aave-v3-core/contracts/interfaces/Ipool.sol";

interface Token {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 amount) external; // Add mint function
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

  Pool poolContract;
  MockToken public testToken;
  Config cfg;

  uint256 percentage = 1;

  address private constant usdcContractAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  function setUp() public {

    cfg = new Config();

    poolContract = new Pool(percentage, 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5, address(cfg));
    testToken = new MockToken("USDC", "USDC");
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

  // function test_supply() public {
  //   address testAddress = address(0x126); 
  //
  //   uint256 amountToSupply = 50 * (10 ** testToken.decimals());
  //   testToken.mint(testAddress, amountToSupply);
  //
  //   vm.startPrank(testAddress); 
  //
  //   testToken.approve(address(poolContract), amountToSupply);
  //
  //   poolContract.supply(address(testToken),amountToSupply);
  //
  //   assertEq(poolContract.balanceOf(address(testToken)), amountToSupply);
  //   vm.stopPrank(); 
  //
  //   // since we have drawn everything off
  //   assertEq(testToken.balanceOf(testAddress),0);
  //
  //   // make sure the contract has the correct and expected amount
  //   assertEq(testToken.balanceOf(address(poolContract)),amountToSupply);
  // }
}
