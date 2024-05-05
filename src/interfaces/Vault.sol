// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.23;

// Vault is a simple subset of the IPool Aave interface. 
// This is extracted to also simplify our testing and mocks really
// Vault or TokenVault
interface Vault {
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function withdraw(address asset, uint256 amount, address to) external;
}

interface NativeVault {
  function depositETH(address, address onBehalfOf, uint16 referralCode) external payable;
  function withdrawETH(address asset, uint256 amount, address to) external;
}
