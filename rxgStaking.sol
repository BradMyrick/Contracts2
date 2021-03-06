// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/**
 * @notice BradMyrick updates to contract
 * @dev Fallback and Receiver functions added to solve the "don't send tokens to the contract" issue
 * @dev The contract now requires that the staking token is the same as the reward token.
 * @dev ReentrancyGuard added to prevent reentrancy attacks.
 * @author @BradMyrick
 */

/**
 * @title Staking Rewards Single Token
 * @notice A contract that distributes rewards to stakers. It requires that the staking token is
 * the same as the reward token. This is much more efficient than Synthetix' version.
 * @dev For funding the contract, use `addReward()`. DO NOT DIRECTLY SEND TOKENS TO THE CONTRACT!
 * @dev Limitations (checked through input sanitization):
 *        1) The sum of all tokens added through `addReward()` cannot exceed `2**96-1`,
 *        2) A user's staked balance cannot exceed `2**96-1`.
 * @dev Assumptions (not checked, assumed to be always true):
 *        1) `block.timestamp < 2**64 - 2**32`,
 *        2) rewardToken returns false or reverts on failing transfers,
 *        3) Number of users does not exceed `(2**256-1)/(2**96-1)`.
 * @author shung
 */


contract StakingRewards is AccessControl, ReentrancyGuard{
// structs
    struct User {
        uint160 rewardPerTokenPaid;
        uint96 balance;
    }
// mappings
    mapping(address => User) public users;
// variables
    uint160 public rewardPerTokenStored;
    uint96 public lastUpdate;

    uint96 public rewardRate;
    uint64 public periodFinish;
    uint96 private totalRewardAdded;

    uint256 public totalStaked;
    uint256 public periodDuration = 1 days;

    uint256 private constant PRECISION = type(uint64).max;
    uint256 private constant MAX_ADDED = type(uint96).max;
    uint256 private constant MAX_PERIOD = type(uint32).max;
    uint256 private constant MAX_BALANCE = type(uint96).max;

    bytes32 private constant FUNDER_ROLE = keccak256("FUNDER_ROLE");
    bytes32 private constant DURATION_ROLE = keccak256("DURATION_ROLE");

    IERC20 public immutable rewardToken;
// events
    event Staked(address indexed user, uint256 amount, uint256 rewards);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event Harvested(address indexed user, uint256 reward);
    event Compounded(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event PeriodDurationUpdated(uint256 newDuration);

    error InvalidAmount(uint256 amount);
    error InvalidDuration(uint256 duration);
    error BalanceOverflow(uint256 balance);
    error DistributionOverflow(uint256 distributed);
    error NoReward();
    error FailedTransfer();
    error ZeroAddress();
    error OngoingPeriod();
// modifiers
    modifier updateRewardPerTokenStored() {
        unchecked {
            if (totalStaked != 0) {
                rewardPerTokenStored = uint160(
                    rewardPerTokenStored + ((_pendingRewards() * PRECISION) / totalStaked)
                );
            }
            lastUpdate = uint96(block.timestamp);
        }
        _;
    }
// constructor
    constructor(address newRewardToken, address newAdmin) {
        unchecked {
            if (newRewardToken == address(0) || newAdmin == address(0)) revert ZeroAddress();
            rewardToken = IERC20(newRewardToken);
            _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
            _grantRole(FUNDER_ROLE, newAdmin);
            _grantRole(DURATION_ROLE, newAdmin);
        }
    }
// fallback/receiver
    receive() external payable {
        revert("Only fund the contract with addReward(amount)");
    }
    fallback()  external payable {
        revert("Not a valid function");
    }
// functions
    function stake(uint256 amount) external updateRewardPerTokenStored nonReentrant() {
        unchecked {
            if (amount == 0 || amount > MAX_BALANCE) revert InvalidAmount(amount);
            User storage user = users[msg.sender];
            uint256 oldBalance = user.balance;
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 rewardPerTokenPayable = rewardPerToken - user.rewardPerTokenPaid;
            uint256 reward = (oldBalance * rewardPerTokenPayable) / PRECISION;
            uint256 totalAmount = amount + reward;
            uint256 newBalance = oldBalance + totalAmount;
            if (newBalance > MAX_BALANCE) revert BalanceOverflow(newBalance);
            totalStaked += totalAmount;
            user.balance = uint96(newBalance);
            user.rewardPerTokenPaid = uint160(rewardPerToken);
            if (!rewardToken.transferFrom(msg.sender, address(this), amount)) {
                revert FailedTransfer();
            }
            emit Staked(msg.sender, amount, reward);
        }
    }

    function harvest() external updateRewardPerTokenStored nonReentrant(){
        unchecked {
            User storage user = users[msg.sender];
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 rewardPerTokenPayable = rewardPerToken - user.rewardPerTokenPaid;
            uint256 reward = (user.balance * rewardPerTokenPayable) / PRECISION;
            if (reward == 0) revert NoReward();
            user.rewardPerTokenPaid = rewardPerToken;
            if (!rewardToken.transfer(msg.sender, reward)) revert FailedTransfer();
            emit Harvested(msg.sender, reward);
        }
    }

    function withdraw(uint256 amount) external updateRewardPerTokenStored nonReentrant() {
        unchecked {
            User storage user = users[msg.sender];
            uint256 oldBalance = user.balance;
            if (amount == 0 || amount > oldBalance) revert InvalidAmount(amount);
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 rewardPerTokenPayable = rewardPerToken - user.rewardPerTokenPaid;
            uint256 reward = (oldBalance * rewardPerTokenPayable) / PRECISION;
            totalStaked -= amount;
            user.balance = uint96(oldBalance - amount);
            user.rewardPerTokenPaid = rewardPerToken;
            if (!rewardToken.transfer(msg.sender, amount + reward)) revert FailedTransfer();
            emit Withdrawn(msg.sender, amount, reward);
        }
    }

    function compound() external updateRewardPerTokenStored {
        unchecked {
            User storage user = users[msg.sender];
            uint256 oldBalance = user.balance;
            uint160 rewardPerToken = rewardPerTokenStored;
            uint256 rewardPerTokenPayable = rewardPerToken - user.rewardPerTokenPaid;
            uint256 reward = (oldBalance * rewardPerTokenPayable) / PRECISION;
            if (reward == 0) revert NoReward();
            uint256 newBalance = oldBalance + reward;
            if (newBalance > MAX_BALANCE) revert BalanceOverflow(newBalance);
            totalStaked += reward;
            user.balance = uint96(newBalance);
            user.rewardPerTokenPaid = rewardPerToken;
            emit Compounded(msg.sender, reward);
        }
    }

    function addReward(uint256 amount) external onlyRole(FUNDER_ROLE) updateRewardPerTokenStored nonReentrant() {
        unchecked {
            uint256 tmpPeriodFinish = periodFinish;
            uint256 tmpPeriodDuration = periodDuration;
            if (amount == 0 || amount > MAX_ADDED) revert InvalidAmount(amount);
            uint256 newTotalRewardAdded = totalRewardAdded + amount;
            if (newTotalRewardAdded > MAX_ADDED) revert DistributionOverflow(newTotalRewardAdded);
            totalRewardAdded = uint96(newTotalRewardAdded);
            if (block.timestamp >= tmpPeriodFinish) {
                rewardRate = uint96(amount / tmpPeriodDuration);
            } else {
                uint256 leftover = (tmpPeriodFinish - block.timestamp) * rewardRate;
                rewardRate = uint96((amount + leftover) / tmpPeriodDuration);
            }
            periodFinish = uint64(block.timestamp + tmpPeriodDuration);
            if (!rewardToken.transferFrom(msg.sender, address(this), amount)) {
                revert FailedTransfer();
            }
            emit RewardAdded(amount);
        }
    }

    function setPeriodDuration(uint256 newDuration) external onlyRole(DURATION_ROLE) {
        unchecked {
            if (periodFinish >= block.timestamp) revert OngoingPeriod();
            if (newDuration == 0 || newDuration > MAX_PERIOD) revert InvalidDuration(newDuration);
            periodDuration = newDuration;
            emit PeriodDurationUpdated(newDuration);
        }
    }

    function earned(address account) external view returns (uint256) {
        unchecked {
            User memory user = users[account];
            uint256 rewardPerToken = totalStaked == 0
                ? rewardPerTokenStored
                : rewardPerTokenStored + (_pendingRewards() * PRECISION) / totalStaked;
            return (user.balance * (rewardPerToken - user.rewardPerTokenPaid)) / PRECISION;
        }
    }

    function _pendingRewards() private view returns (uint256) {
        unchecked {
            uint256 tmpPeriodFinish = periodFinish;
            uint256 lastTimeRewardApplicable = tmpPeriodFinish < block.timestamp
                ? tmpPeriodFinish
                : block.timestamp;
            uint256 tmpLastUpdate = lastUpdate;
            uint256 duration = lastTimeRewardApplicable > tmpLastUpdate
                ? lastTimeRewardApplicable - tmpLastUpdate
                : 0;
            return duration * rewardRate;
        }
    }
}