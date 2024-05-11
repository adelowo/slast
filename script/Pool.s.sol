// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import "../src/Pool.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PoolScript is Script {
    function setUp() public {}

    function run() public {
      uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
      vm.startBroadcast(deployerPrivateKey);

      Pool poolVault = new Pool();
      // Deploy Proxy (UUPS)
      bytes memory data = abi.encodeCall(
        poolVault.initialize, (0,0xA238Dd80C259a72e81d7e4664a9801593F98d1c5, 0x5081a39b8a5f0e35a8d959395a630b68b74dd30f, 0x8be473dCfA93132658821E67CbEB684ec8Ea2E74) 
      );

      address proxyAddress = address(new ERC1967Proxy(address(impl), data));

      console.log(proxyAddress);
    }
}
