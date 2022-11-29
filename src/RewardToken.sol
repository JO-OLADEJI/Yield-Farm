// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IRewardToken.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract RewardToken is ERC20, IRewardToken {
    constructor() ERC20("RewardToken", "RWTN") {}

    function mint(address _account, uint256 _amount) external override {
        _mint(_account, _amount);
    }
}
