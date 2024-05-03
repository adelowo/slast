// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.23;

import {Test,console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/vaults/Aave.sol";


contract AaveTest is Test {

  Aave aaveVault;

  address private constant baseAavePoolAddress = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

  address private constant usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  function setUp() public {
    aaveVault = new Aave(baseAavePoolAddress);
  }


  function test_randomUserAddsAsset() public {
    address testAddress = address(0x123); 

    vm.startPrank(testAddress); 

    vm.expectRevert(); 

    aaveVault.addSupportedAsset(usdcAddress);

    vm.stopPrank(); 
  }

  function test_assetCanBeAdded() public {
    vm.expectEmit(true,true,true,true,address(aaveVault));
    emit NewSupportedToken(usdcAddress);

    aaveVault.addSupportedAsset(usdcAddress);
  }


  function test_assetCannotBeAddedMultipleTimes() public {
    vm.expectEmit(true,true,true,true,address(aaveVault));
    emit NewSupportedToken(usdcAddress);

    aaveVault.addSupportedAsset(usdcAddress);

    // add the same asset again
    // this should fail
    vm.expectRevert(bytes("This asset was previously added"));
    aaveVault.addSupportedAsset(usdcAddress);


    // add a new different asset. 
    // make sure it passes
    aaveVault.addSupportedAsset(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  }

  function test_isSupported() public {

    assertFalse(aaveVault.isSupported(usdcAddress));

    aaveVault.addSupportedAsset(usdcAddress);

    assertTrue(aaveVault.isSupported(usdcAddress));
  }


  function test_pauseAssetSupply() public {

    // add the asset
    aaveVault.addSupportedAsset(usdcAddress);


    // pause the supply for the asset
    vm.expectEmit(true,true,true,true,address(aaveVault));
    emit AssetSupplyPaused(usdcAddress);

    aaveVault.pauseAssetSupply(usdcAddress);
  }
}
