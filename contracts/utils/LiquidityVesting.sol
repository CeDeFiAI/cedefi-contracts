// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Liquidity Vesting Contract
/// @author CDFi
/// @notice Contract for vesting tokens to a liquidity provider over a period of time
contract LiquidityVesting is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    /// @notice Total number of tokens allocated for vesting
    uint256 public constant TOTAL_TOKENS = 55555555 * 1e18;

    uint256 public constant CLIFF = 3 * 30 days; // 3 months

    /// @notice Duration of the vesting period in days
    uint256 public constant VESTING_DURATION = 24 * 30 days;

    uint256 public withdrawnTokens;

    /// @notice Start time for vesting period
    uint256 public startTime;

    /// @notice Wallet address to receive vested tokens
    address public teamWallet;

    // Events

    /// @notice Emitted when token address is set
    /// @param tokenAddress Address of token contract
    event TokenAddressSetted(address indexed tokenAddress);

    /// @notice Emitted when vested tokens are withdrawn
    /// @param teamWallet Wallet tokens were sent to
    /// @param amount Amount of tokens withdrawn
    event TokenClaimed(address indexed teamWallet, uint256 indexed amount);

    /// @notice Emitted when vesting period starts
    /// @param startTime Start time in UNIX timestamp
    event VestingStarted(uint256 indexed startTime);

    event TeamWalletChanged(address indexed teamWalletAddress);

    // Constructor

    /// @param _tokenAddress Address of token
    /// @param _owner Address of the smart contract owner
    constructor(
        address _tokenAddress,
        address _teamWallet,
        address _owner
    ) Ownable(_owner) {
        require(_tokenAddress != address(0), "Zero address!");
        token = IERC20(_tokenAddress);
        require(_teamWallet != address(0), "Zero address!");
        teamWallet = _teamWallet;
    }

    // External functions

    /// @notice Starts the vesting period
    function startVesting() external onlyOwner {
        require(startTime == 0, "Vesting already started!");
        startTime = block.timestamp + CLIFF;
        emit VestingStarted(startTime);
    }

    /// @notice Sets the token address
    /// @param tokenAddress ERC20 token address
    function setTokenAddress(address tokenAddress) external onlyOwner {
        token = IERC20(tokenAddress);
        emit TokenAddressSetted(tokenAddress);
    }

    /// @notice Changes the team wallet address
    /// @param newTeamWallet New wallet address
    function setTeamWallet(address newTeamWallet) external onlyOwner {
        require(newTeamWallet != address(0), "Zero address!");
        teamWallet = newTeamWallet;
        emit TeamWalletChanged(newTeamWallet);
    }

    /// @notice Withdraws vested tokens to the team wallet
    function withdrawVestedTokens() external onlyOwner {
        require(startTime != 0, "Vesting not started yet!");
        require(teamWallet != address(0), "Team wallet not been setted yet.");
        uint256 vestedTokens = vestedAmount();
        uint256 currentBalance = token.balanceOf(address(this));

        vestedTokens = currentBalance >= vestedTokens
            ? vestedTokens
            : currentBalance;
        withdrawnTokens += vestedTokens;
        token.safeTransfer(teamWallet, vestedTokens);
        emit TokenClaimed(teamWallet, vestedTokens);
    }

    // Internal functions

    /// @notice Calculates vested tokens at current time
    /// @return Vested token amount
    function vestedAmount() public view returns (uint256) {
        if (withdrawnTokens >= TOTAL_TOKENS) {
            return 0;
        }
        if (startTime == 0) {
            return 0;
        }
        uint256 currentTime = block.timestamp;
        require(currentTime >= startTime, "Vesting under cliff!");
        if (currentTime >= startTime + VESTING_DURATION) {
            return token.balanceOf(address(this));
        }
        uint256 timePassed = currentTime - startTime;
        uint256 vested = (timePassed * TOTAL_TOKENS) / VESTING_DURATION;
        if (vested < withdrawnTokens) {
            return 0;
        }
        uint256 availableTokens = vested - withdrawnTokens;
        return availableTokens;
    }

    receive() external payable{}
}
