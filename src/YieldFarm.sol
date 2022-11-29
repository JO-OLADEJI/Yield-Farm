// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract YieldFarm {
    /// @notice Struct storing the info of a staker (yield farmer)
    /// - id: Address of the staker
    /// - blockRewardIndex: Index of the last block in `_txBlocks[]` used to calculate farm rewards
    struct Farmer {
        address id;
        uint96 blockRewardIndex;
        uint256 stake;
        uint256 cachedRewards;
    }

    uint256 public constant DIVISION_PRECISION = 1e12;
    address public rewardToken;

    /// @notice Track blocks where `deposit()` or `withdraw()` tx
    uint256[] private _txBlocks;

    /// @notice Block number => Tokens locked
    mapping(uint256 => uint256) private _tvlSnapshot;
    mapping(address => Farmer) private _farmers;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function getAccumulatedRewards(address _farmer)
        external
        view
        returns (uint256 _accumulatedRewards)
    {
        // return cachedRewards + (accumulated rewards) -> if stake > 0
    }

    /// @notice Stake tokens for proportional rewards
    /// @param _amount Amount of tokens to stake
    function deposit(uint256 _amount) external {
        // add the current block to _txBlocks
        _txBlocks.push(block.number);

        Farmer storage farmer = _farmers[msg.sender];
        require(farmer.stake != 0);

        // cache rewards to staker and update BRI
        farmer.cachedRewards += _getAccumulatedRewards(farmer);

        // transfer ERC20 token to this smart contract
        // rewardToken.transferFrom(msg.sender, address(this) _amount);

        // fill the blockNumber to total tokens mapping
        // _tvlSnapshot[block.number] = rewardToken.balanceOf(address(this));
    }

    function withdraw() external {}

    function withdraw(uint256 _amount) external {}

    function claimRewards() external {}

    function claimRewards(uint256 _amount) external {}

    function withdrawAndClaimRewards() external {}

    function withdrawAndClaimRewards(uint256 _amount) external {}

    function _claimRewards() private {
        Farmer storage farmer = _farmers[msg.sender];
        uint256 accumulatedRewards = _getAccumulatedRewards(farmer);
        farmer.blockRewardIndex = uint96(_txBlocks.length - 1);

        // rewardToken.mint(farmer.id, accumulatedRewards);
    }

    function _getAccumulatedRewards(Farmer memory _farmer)
        private
        view
        returns (uint256 _accumulatedRewards)
    {
        for (uint256 i = _farmer.blockRewardIndex; i < _txBlocks.length - 1; ) {
            _accumulatedRewards +=
                (_farmer.stake *
                    (_txBlocks[i + 1] - _txBlocks[i]) *
                    DIVISION_PRECISION) /
                _tvlSnapshot[_txBlocks[i]];
            unchecked {
                ++i;
            }
        }
        _accumulatedRewards /= DIVISION_PRECISION;
    }
}
