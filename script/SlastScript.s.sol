// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import "../src/Slast.sol";
import "../src/Config.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract SlastScript is Script {
    function setUp() public {}

    address private constant AAVE_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address private constant AAVE_WETH_GATEWAY = 0x8be473dCfA93132658821E67CbEB684ec8Ea2E74;

    function run() public {

      uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
      vm.startBroadcast(deployerPrivateKey);

      Slast slastPool = new Slast();
      Config cfg = new Config();
      console.log("config deployed to:", address(cfg));
      console.log("slast deployed to:", address(slastPool));

      address proxy = Upgrades.deployUUPSProxy(
        "Slast.sol",
        abi.encodeCall(slastPool.initialize, (0,AAVE_POOL,address(cfg), AAVE_WETH_GATEWAY))
      );

      console.log("Proxy ",proxy);
    }
}
