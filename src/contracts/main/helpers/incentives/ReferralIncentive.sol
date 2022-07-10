/*
    Copyright 2022 Translucent.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache-2.0
*/

pragma solidity ^0.8.12;

// External libraries
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Code
import "../../../../lib/Decimals.sol";
import "./Incentive.sol";

/**
 * @title ReferralIncentive
 * @author Translucent
 *
 * @notice Contract for the main fund's referral incentive program.
 *
 * @dev We adopt a similar strategy as lending pools of using an exchange rate
 *      to track the accruing of rewards but instead of using a token, we track
 *      it internally with a balance and its corrresponding exchange rate.
 *      This allows for the non-homogenous nature of the the sharing of rewards
 *      with referrers which cannot be represented by fungible tokens.
 */
contract ReferralIncentive is ReentrancyGuard, Incentive {
    using SafeERC20 for IMainFundToken;
    using Decimals for Decimals.Number;

    /** Constants */
    uint256 public constant PROFIT_SHARING_PERCENT = 0.1 ether; // 10%
    uint256 public constant REFERRER_SHARE_PERCENT = 0.5 ether; // 50%
    uint256 public constant MAX_REFEREES_PER_REFERRER = 10;

    /** Structs */
    struct User {
        address referrer;
        address[] referees;
        uint256 balance;
        uint256 exchangeRate;
    }

    /** States */
    mapping(address => User) private _users;
    uint256 private _exchangeRate = 1 ether; // initial rate is 1:1

    /** Constructor */
    constructor(address fundAddress) Incentive(fundAddress) {}

    /************************************/
    /** Functions to serve as modifiers */
    /************************************/
    /**
     * Function to be called by the incentives manager and internally to ensure
     * that only registered referees can call the top-level function.
     *
     * @param userAddress - The address to check.
     * @return - Whether the user qualifies or not.
     */
    function checkUserQualifies(
        address userAddress
    ) public view override returns (bool) {
        // Qualification based on registration status
        return _users[userAddress].referrer != address(0);
    }

    /** Internal modifiers */
    modifier onlyQualified(address caller) {
        require(
            checkUserQualifies(caller),
            "ReferralIncentive: user is not registered"
        );
        _;
    }


    /************************************/
    /** Functions for users to interact */
    /************************************/
    /**
     * Helper function to read the current exchange rate.
     *
     * @return - The current exchange rate.
     */
    function getExchangeRate() external view returns (uint256) {
        return _exchangeRate;
    }

    /**
     * Gets a user's struct details.
     *
     * @param userAddress - The address of the user to read.
     * @return - The user's struct details.
     */
    function getUser(address userAddress) external view returns (User memory) {
        return _users[userAddress];
    }

    /**
     * Registers a user by linking the user with a referrer.
     *
     * @param referrerAddress - The address of the referrer.
     */
    function register(address referrerAddress) external {
        // Retrieve the reference to the user struct in storage
        User storage user = _users[_msgSender()];

       // Cannot register if already registered (be it as referrer or referee)
        require(
            user.referrer == address(0) && user.referees.length == 0,
            "ReferralIncentive: user is already registered"
        );
        // Cannot set referrer to 0x0 address or self
        require(
            referrerAddress != address(0) && referrerAddress != _msgSender(),
            "ReferralIncentive: referrer address invalid"
        );
        // Require that the referrer still has slots for referees
        // This is to prevent excessive iterations on a user's referees
        require(
            _users[referrerAddress].referees.length < MAX_REFEREES_PER_REFERRER,
            "ReferralIncentive: referrer already hit maximum number of referees"
        );

        user.referrer = referrerAddress;
        _users[referrerAddress].referees.push(_msgSender());
    }

    /**
     * Gets the balance of a user.
     *
     * @return - The user's balance.
     */
    function getBalance(address userAddress) external view override returns (uint256) {
        User memory user = _users[userAddress];
        uint256 exchangeRate = _exchangeRate; 

        // Compute the referee rewards
        // No iterations if no referees
        uint256 rewardsAsReferrer = 0;
        for (uint256 i = 0; i < user.referees.length; i++) {
            User memory referee = _users[user.referees[i]];
            (, uint256 referrerRewards) = _computeRewardsWithReferrer(
                referee.balance, referee.exchangeRate, exchangeRate
            );
            rewardsAsReferrer += referrerRewards;
        }

        // No referrer
        if (user.referrer == address(0))
            return user.balance + _computeRewardsNoReferrer(
                user.balance,
                user.exchangeRate,
                _exchangeRate
            ) + rewardsAsReferrer;

        // With referrer
        (uint256 userRewards, ) = _computeRewardsWithReferrer(
            user.balance, user.exchangeRate, _exchangeRate
        );
        return user.balance + userRewards + rewardsAsReferrer;
    }

    /**
     * Performs the deposit for a registered referee.
     *
     * @notice Cannot be called when paused
     *         e.g. to retire the incentive but still
     *         allow users to withdraw any outstanding balances.
     *
     * @param depositAmount - The amount of fund tokens to deposit.
     */
    function deposit(
        uint256 depositAmount
    ) external onlyQualified(_msgSender()) nonReentrant whenNotPaused override {
        // Transfer the fund tokens in from the user
        getFund().getFundToken().safeTransferFrom(
            _msgSender(), address(this), depositAmount
        );

        // Retrieve the reference to the user struct in storage
        User storage user = _users[_msgSender()];

        // Pull the values read more than once into memory
        uint256 exchangeRate = _exchangeRate;
        uint256 userBalance = user.balance;

        // Accrue the referrer's rewards and get back the user's rewards
        uint256 userRewards = _computeRewardsForUserAndUpdateForReferrer(
            user.referrer, userBalance, user.exchangeRate, exchangeRate
        );

        // Update the user struct in storage
        user.balance = userBalance + userRewards + depositAmount;
        user.exchangeRate = exchangeRate;
    }

    /**
     * Performs the withdrawal for a registered referee.
     *
     * @param withdrawalAmount - The amount of fund tokens to withdraw.
     */
    function withdraw(uint256 withdrawalAmount) external nonReentrant override {
        // Retrieve the reference to the user struct in storage
        User storage user = _users[_msgSender()];

        // Pull the values read more than once into memory
        uint256 exchangeRate = _exchangeRate;
        uint256 userBalance = user.balance;

        // Accrue the referrer's rewards and get back the user's rewards
        uint256 userRewards = _computeRewardsForUserAndUpdateForReferrer(
            user.referrer, userBalance, user.exchangeRate, exchangeRate
        );

        // Require that user has enough balance to withdraw
        require(
            withdrawalAmount <= userBalance + userRewards,
            "ReferralIncentive: insufficient balance"
        );

        // Update the user struct in storage
        user.balance = userBalance + userRewards - withdrawalAmount;
        user.exchangeRate = exchangeRate;

        // Transfer the fund tokens to the user
        getFund().getFundToken().safeTransfer(_msgSender(), withdrawalAmount);
    }

    /******************************************************/
    /** Internal helper functions for rewards computation */
    /******************************************************/
    /**
     * Computes the user's rewards when there is no referrer.
     *
     * @param userBalance - The balance struct to compute the accrual with.
     * @param userExchangeRate - The rate to accrue from.
     * @param newExchangeRate - The rate to accrue to.
     * @return - The rewards amount.
     */
    function _computeRewardsNoReferrer(
        uint256 userBalance,
        uint256 userExchangeRate,
        uint256 newExchangeRate
    ) internal pure returns (uint256) {
        return userExchangeRate == 0
            ? 0 // uninitialized exchange rate means not registered / no balance
            : (userBalance * newExchangeRate / userExchangeRate) - userBalance;
    }

    /**
     * Computes the user's rewards when there is a referrer.
     *
     * @param userBalance - The balance struct to compute the accrual with.
     * @param userExchangeRate - The rate to accrue from.
     * @param newExchangeRate - The rate to accrue to.
     * @return - The rewards amount for the user.
     * @return - The rewards amount for the referrer.
     */
    function _computeRewardsWithReferrer(
        uint256 userBalance,
        uint256 userExchangeRate,
        uint256 newExchangeRate
    ) internal pure returns (uint256, uint256) {
        // First compute the total rewards as though there is no referrer
        uint256 totalRewards = _computeRewardsNoReferrer(
            userBalance, userExchangeRate, newExchangeRate
        );

        // Then split the total rewards between the user and the referrer
        uint256 referrerRewards = totalRewards * REFERRER_SHARE_PERCENT / 10**18;
        uint256 userRewards = totalRewards - referrerRewards;

        return (userRewards, referrerRewards);
    }

    /**
     * Accrues the rewards for the referrer and returns the user's rewards.
     *
     * @dev This is an odd pattern of partial updating for the referrer but
     *      not for the user, since we have to include the deposits/withdrawals.
     *      This allows us to not have to update storage twice and save gas.
     *
     * @param referrerAddress - The address of the referrer (0x0 if none)
     * @param userBalance - The balance of the user.
     * @param userExchangeRate - The rate to accrue from.
     * @param newExchangeRate - The rate to accrue to.
     * @return - The rewards for the user.
     */
    function _computeRewardsForUserAndUpdateForReferrer(
        address referrerAddress,
        uint256 userBalance,
        uint256 userExchangeRate,
        uint256 newExchangeRate
    ) internal returns (uint256) {
        // Simple case with no referrer (top-level referrers)
        if (referrerAddress == address(0))
            return _computeRewardsNoReferrer(
                userBalance, userExchangeRate, newExchangeRate
            );

        // With referrer
        uint256 userRewards; uint256 referrerRewards;
        (userRewards, referrerRewards) = _computeRewardsWithReferrer(
            userBalance, userExchangeRate, newExchangeRate
        );

        // Update the referrer's struct in storage
        User storage referrer = _users[referrerAddress];
        referrer.balance += referrerRewards;
        referrer.exchangeRate = newExchangeRate;

        return userRewards;
    }

    /*****************************************/
    /** Functions for the incentives manager */
    /*****************************************/
    /**
     * Computes the dilution weight to be allocated to this incentive.
     *
     * @param periodBeginningSupply - The denominator to compute share of AUM.
     * @return - The dilution weight based on share of AUM and return-weighted allocation.
     */
    function getDilutionWeight(
        Decimals.Number memory periodBeginningSupply,
        Decimals.Number memory returnsFactor
    ) external view override returns (Decimals.Number memory) {
        Decimals.Number memory one = Decimals.Number(1 ether, 18);

        // No referral dilution weight if negative returns
        if (returnsFactor.lte(one))
            return Decimals.Number(0, 18);

        // Compute dilution weight for positive returns
        Decimals.Number memory balance = Decimals.Number(
            getFund().getFundToken().balanceOf(address(this)), 18
        );

        // Share of AUM % x profit-sharing % x returns %
        return balance
            .div(periodBeginningSupply)
            .mul(Decimals.Number(PROFIT_SHARING_PERCENT, 18))
            .mul(returnsFactor.sub(one));
    }

    /**
     * Records a direct deposit from the fund's front office contract.
     *
     * @notice Allows the front office to directly
     *         mint fund tokens into this contract.
     *
     * @param userAddress - The address of the user.
     * @param depositAmount - The amount to record.
     */
    function recordDirectDeposit(
        address userAddress,
        uint256 depositAmount
    ) external override {
        // Only callable by the front office contract
        require(
            _msgSender() == address(getFund().getFrontOffice()),
            "ReferralIncentive: caller is not the front office contract"
        );

        // Retrieve the reference to the user struct in storage
        User storage user = _users[userAddress];

        // Pull the values read more than once into memory
        uint256 exchangeRate = _exchangeRate;
        uint256 userBalance = user.balance;

        // Accrue the referrer's rewards and get back the user's rewards
        uint256 userRewards = _computeRewardsForUserAndUpdateForReferrer(
            user.referrer, userBalance, user.exchangeRate, exchangeRate
        );

        // Update the user struct in storage
        user.balance = userBalance + userRewards + depositAmount;
        user.exchangeRate = exchangeRate;
    }

    /**
     * Records a disbursement from the fund's accounting contract.
     *
     * @param amount - The disbursement amount of fund tokens.
     */
    function recordDisbursement(uint256 amount) external override {
        // Only callable by the accounting contract
        require(
            _msgSender() == address(getFund().getAccounting()),
            "ReferralIncentive: caller is not the accounting contract"
        );

        Decimals.Number memory balance = Decimals.Number(
            getFund().getFundToken().balanceOf(address(this)), 18
        );

        // Update the exchange rate
        // (balance + amount) / (balance) x oldExchangeRate
        _exchangeRate = (balance.add(Decimals.Number(amount, 18)))
            .div(balance)
            .mul(Decimals.Number(_exchangeRate, 18))
            .value;
    }
}
