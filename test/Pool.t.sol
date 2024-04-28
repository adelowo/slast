// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.23;

import {Test,console} from "forge-std/Test.sol";
import "../src/Pool.sol";


contract PoolTest is Test {

  Pool poolContract;

  uint256 percentage = 1;

  address private constant DEAD_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function setUp() public {
    poolContract = new Pool(percentage);
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
}
