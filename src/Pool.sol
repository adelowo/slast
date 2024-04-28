// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {console} from "forge-std/Test.sol";

contract Pool {
    uint256 public feePercentage;

    struct HoldingsInfo {
        uint256 amount;
    }

    mapping(address => HoldingsInfo) balanceMappings;

    // We use this as a token address to identiy ETH native token
    // we don't send anything to the burn address EVER
    address private constant DEAD_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // user balance ==> toekn address ==> balance
    // 0x000000000000000000000000000000000000dEaD will be used for ETH
    mapping(address => mapping(address => uint256)) private userHoldings;

    event Deposit(address indexed from, address indexed token, uint256 amount);

    constructor(uint256 _feePercentage) {
        feePercentage = _feePercentage;
    }



    function depositNativeToken() public payable {
      userHoldings[msg.sender][DEAD_ADDRESS] += msg.value;
      emit Deposit(msg.sender,DEAD_ADDRESS,msg.value);
    }

    function getFee() external view returns (uint256) {
      return feePercentage;
    }

    function getNativeTokenBalance() public view returns (uint256)  {
      return userHoldings[msg.sender][DEAD_ADDRESS];
    }
}
