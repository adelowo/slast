// SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;

interface Vault {
  function supply(address asset, uint256 amount) external;
  function isSupported(address asset) external returns (bool);
  function addSupportedAsset(address asset) external;
  function pauseAssetSupply(address asset) external;
}
