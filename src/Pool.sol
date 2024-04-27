// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DepositPool {
    uint256 public feePercentage;

    struct BalanceInfo {
        uint256 amount;
        address tokenAddress;
    }

    mapping(address => BalanceInfo) balanceMappings;

    // We use this as a token address to identiy ETH native token
    // we don't send anything to the burn address EVER
    const DEAD_ADDRESS = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

    // user balance ==> toekn address ==> balance
    // 0x000000000000000000000000000000000000dEaD will be used for ETH
    mapping(address => mappings(address => uint256)) userHoldings;

    event Deposit(address indexed fromfrom, address indexed token, uint256 amount);

    constructor(uint256 _feePercentage) {
        feePercentage = _feePercentage;
    }

    function supply(address token, uint256 amount) external {
       require(amount <= 0, "Amount must be greater than zero");

        // Transfer tokens from the sender to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Calculate the amount to withhold
        uint256 feeAmount = (amount * feePercentage) / 100;

        balanceMappings[msg.sender] = UserInfo(feeAmount, token);

        // Emit deposit event
        emit Deposit(msg.sender, token, amount);

        // Forward the remaining tokens to the address
        uint256 remainingAmount = amount - feeAmount;
        IERC20(token).transferFrom(address(this), receiver, remainingAmount);
    }

    function deposit() payable {
        balanceMappings[msg.sender][DEAD_ADDRESS] += msg.value;
    }
}
