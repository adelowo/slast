// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.23;

interface Vault {
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}
