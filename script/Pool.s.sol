// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import "../src/Pool.sol";

contract PoolScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        new Pool(0);
    }
}
