// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/IRewardToken.sol";
import "./interfaces/IYieldFarm.sol";

/// @title YieldFarm
/// @notice Alternative MasterChef contract implementation
/// @author Joshua Oladeji <analogdev.eth>
contract YieldFarm is IYieldFarm, Ownable, ReentrancyGuard {
    /// @dev See {IYieldFarm - trackedTvl}
    uint256 public override trackedTvl;
    /// @dev See {IYieldFarm - rewardPerBlock}
    uint256 public override rewardPerBlock;
    /// @notice Number used to preserve precision when dividing
    uint256 public constant DIVISION_PRECISION = 1e12;

    /// @dev See {IYieldFarm - stakeToken}
    IERC20 public override stakeToken;
    /// @dev See {IYieldFarm - rewardToken}
    IRewardToken public override rewardToken;

    /// @notice Track blocks where a yield farmer deposits or withdraws
    uint256[] private _txBlocks;

    /// @notice Block number => amount of staked tokens
    mapping(uint256 => uint256) private _blockTvlSnapshot;
    /// @notice Address of yield farmer => yield farm info of farmer
    mapping(address => Farmer) private _farmers;

    /// @notice Constructor
    /// @param _stakeToken Address of ERC20 token staked in this yield farm
    /// @param _rewardToken Address of ERC2O token to be minted to yield farmers
    /// @param _rewardPerBlock Amout of reward tokens created per block
    constructor(
        IERC20 _stakeToken,
        IRewardToken _rewardToken,
        uint256 _rewardPerBlock
    ) {
        require(_rewardPerBlock > 0);

        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
    }

    /// @dev See {IYieldFarm - getAccumulatedRewards}
    function getAccumulatedRewards(address _farmer)
        external
        view
        override
        returns (uint256 _accumulatedRewards)
    {
        Farmer storage farmer = _farmers[_farmer];
        _accumulatedRewards = farmer.cachedRewards;

        if (farmer.stake > 0) {
            _accumulatedRewards += _getAccumulatedRewards(farmer);
        }
    }

    /// @dev See {IERC165 - supportsInterface}
    function supportsInterface(bytes4 _interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return _interfaceId == type(IYieldFarm).interfaceId;
    }

    /// @dev See {IYieldFarm - claimRewards}
    function claimRewards() external override nonReentrant {
        _claimRewards(type(uint256).max);
    }

    /// @dev See {IYieldFarm - claimRewards(uint256)}
    function claimRewards(uint256 _amount) external override nonReentrant {
        _claimRewards(_amount);
    }

    /// @dev See {IYieldFarm - deposit}
    function deposit(uint256 _amount) external override nonReentrant {
        Farmer storage farmer = _farmers[msg.sender];
        _syncTvl(_amount, true);

        farmer.stake += _amount;
        farmer.cachedRewards += _getAccumulatedRewards(farmer);
        farmer.blockRewardIndex = _txBlocks.length - 1;

        stakeToken.transferFrom(msg.sender, address(this), _amount);
    }

    /// @dev See {IYieldFarm - depositAndClaimRewards}
    function depositAndClaimRewards(uint256 _amount)
        external
        override
        nonReentrant
    {
        _claimRewards(type(uint256).max);

        Farmer storage farmer = _farmers[msg.sender];
        _syncTvl(_amount, true);

        farmer.stake += _amount;

        stakeToken.transferFrom(msg.sender, address(this), _amount);
    }

    /// @dev See {IYieldFarm - withdraw}
    function withdraw() external override nonReentrant {
        Farmer storage farmer = _farmers[msg.sender];
        _syncTvl(farmer.stake, false);

        farmer.stake = 0;
        farmer.cachedRewards += _getAccumulatedRewards(farmer);
        farmer.blockRewardIndex = _txBlocks.length - 1;

        stakeToken.transferFrom(address(this), msg.sender, farmer.stake);
    }

    /// @dev See {IYieldFarm - withdraw(uint256)}
    function withdraw(uint256 _amount) external override nonReentrant {
        Farmer storage farmer = _farmers[msg.sender];
        require(farmer.stake >= _amount);
        _syncTvl(_amount, false);

        farmer.stake -= _amount;
        farmer.cachedRewards += _getAccumulatedRewards(farmer);
        farmer.blockRewardIndex = _txBlocks.length - 1;

        stakeToken.transferFrom(address(this), msg.sender, _amount);
    }

    /// @dev See {IYieldFarm - withdrawAndClaimRewards}
    function withdrawAndClaimRewards() external override nonReentrant {
        _claimRewards(type(uint256).max);

        Farmer storage farmer = _farmers[msg.sender];
        _syncTvl(farmer.stake, false);

        farmer.stake = 0;

        stakeToken.transferFrom(address(this), msg.sender, farmer.stake);
    }

    /// @notice Claims rewards to `msg.sender`
    /// @dev _amount must not be higher than accumulated rewards
    /// @dev If `_amount` equals type(uint256).max, claim all rewards
    /// @param _amount Amount of accumulated rewards to claim
    function _claimRewards(uint256 _amount) private {
        Farmer storage farmer = _farmers[msg.sender];
        require(farmer.stake > 0 || farmer.cachedRewards > 0);

        uint256 accumulatedRewards = _getAccumulatedRewards(farmer) +
            farmer.cachedRewards;
        if (_amount == type(uint256).max) {
            farmer.cachedRewards = 0;
        } else {
            require(accumulatedRewards >= _amount);
            farmer.cachedRewards = accumulatedRewards - _amount;
        }
        farmer.blockRewardIndex = _txBlocks.length - 1;

        rewardToken.mint(farmer.id, accumulatedRewards);
    }

    /// @notice Keeps track of deposited stake tokens in YieldFarm
    /// @notice Keeps track of stake tokens TVL at current block
    /// @notice Add current block to blocks in which a farmer deposits or withdraws staked tokens
    function _syncTvl(uint256 _amount, bool _deposit) private {
        trackedTvl = _deposit ? trackedTvl + _amount : trackedTvl - _amount;
        _blockTvlSnapshot[block.number] = trackedTvl;

        if (_txBlocks[_txBlocks.length - 1] != block.number) {
            _txBlocks.push(block.number);
        }
    }

    /// @notice Calculate the accumulated rewards of a yield farmer from a particular block
    /// @param _farmer Yield farm info of a farmer
    /// @return _accumulatedRewards Calculated rewards of yield farmer
    function _getAccumulatedRewards(Farmer memory _farmer)
        private
        view
        returns (uint256 _accumulatedRewards)
    {
        if (_farmer.stake == 0) return 0;
        // manage case where _txBlocks.length <= 2
        for (uint256 i = _farmer.blockRewardIndex; i < _txBlocks.length - 1; ) {
            _accumulatedRewards +=
                (rewardPerBlock *
                    _farmer.stake *
                    (_txBlocks[i + 1] - _txBlocks[i]) *
                    DIVISION_PRECISION) /
                _blockTvlSnapshot[_txBlocks[i]];
            unchecked {
                ++i;
            }
        }
        _accumulatedRewards /= DIVISION_PRECISION;
    }
}
