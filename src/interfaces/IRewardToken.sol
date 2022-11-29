// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

interface IRewardToken is IERC20 {
	/// @notice Function to mint new tokens to an address
	/// @param _account Address to mint tokens to
	/// @param _amount Amount of tokens to mint
	/// NOTE: Amount should be formatted to the right number of decimals
    function mint(address _account, uint256 _amount) external;
}
