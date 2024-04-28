// SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;


interface Vault {
  function supply(address asset, uint256 amount) external;
}
