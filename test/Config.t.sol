
// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.23;

import {Test,console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Config.sol";


contract ContractTest is Test {

  address private constant baseAavePoolAddress = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

  address private constant usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  Config cfg;

  function setUp() public {
    cfg = new Config();
  }

  function test_randomUserAddsAsset() public {
    address testAddress = address(0x123); 

    vm.startPrank(testAddress); 

    vm.expectRevert(); 

    cfg.addSupportedAsset(usdcAddress);

    vm.stopPrank(); 
  }

  function test_assetCanBeAdded() public {
    vm.expectEmit(true,true,true,true,address(cfg));
    emit NewSupportedToken(usdcAddress);

    cfg.addSupportedAsset(usdcAddress);
  }


  function test_assetCannotBeAddedMultipleTimes() public {
    vm.expectEmit(true,true,true,true,address(cfg));
    emit NewSupportedToken(usdcAddress);

    cfg.addSupportedAsset(usdcAddress);

    // add the same asset again
    // this should fail
    vm.expectRevert(bytes("This asset was previously added"));
    cfg.addSupportedAsset(usdcAddress);


    // add a new different asset. 
    // make sure it passes
    cfg.addSupportedAsset(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  }

  function test_isSupported() public {

    assertFalse(cfg.isSupported(usdcAddress));

    cfg.addSupportedAsset(usdcAddress);

    assertTrue(cfg.isSupported(usdcAddress));
  }


  function test_pauseAssetSupply() public {

    // add the asset
    cfg.addSupportedAsset(usdcAddress);


    // pause the supply for the asset
    vm.expectEmit(true,true,true,true,address(cfg));
    emit AssetSupplyPaused(usdcAddress);

    cfg.pauseAssetSupply(usdcAddress);
  }
}
