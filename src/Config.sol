// SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;

import "./interfaces/Configuration.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "aave-v3-core/contracts/interfaces/Ipool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

event NewSupportedToken(address indexed asset);
event AssetSupplyPaused(address indexed asset);

contract Config is Configuration, Ownable(msg.sender) {

  struct Asset {
    address asset;

    // we can support an aset but temporarily restrict 
    // it from getting supplied as an example
    // by default this should be true
    bool isPaused;
  }

  mapping(address => Asset) private supportedAssets;

  mapping(address => bool) private checkList;


  function addSupportedAsset(address asset) external onlyOwner {
    require(!checkList[asset], "This asset was previously added");

    supportedAssets[asset] = Asset(asset,false);
    checkList[asset] = true;
    emit NewSupportedToken(asset);
  }

  function isSupported(address asset) external view returns (bool) {
    return checkList[asset];
  }

  function pauseAssetSupply(address asset) external onlyOwner {
    require(checkList[asset], "This asset is not currently supported. Add it first");

    supportedAssets[asset].isPaused = true;
    emit AssetSupplyPaused(asset);
  }
}
