/**
 * Interactions Suite 1 Script for the Main Fund.
 *
 * Integration tests for the individual sequences of transactions
 * in deposits/withdrawals and working with the referral incentive.
 */

// Types
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { ContractsState, MainFund, Token, AccountingState } from "../interfaces";

// Library
import { ethers } from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";

// Code
import helpers from "../helpers";

/** Regular deposit multiple times */
const interactMultipleDepositsAndWithdrawals = async (
    fund: MainFund,
    users: SignerWithAddress[],
    token: Token,
    verbose: boolean
): Promise<void> => {
    console.log(" --- bsc > interact > suite1 > multipleDepositsAndWithdrawals > start --- ");

    // States to be set by deposit and used in withdrawal
    let usersTokensDeposited: BigNumber[];
    let usersFundTokensReceived: BigNumber[];

    // deposits
    {
        console.log(" --- bsc > interact > suite1 > multipleDepositsAndWithdrawals > deposits > start --- ");
        // Track states
        const usersTokenBalancesBeforeRequests: BigNumber[] = await Promise.all(
            users.map(async (user) => await token.token.balanceOf(user.address))
        );
        const foTokenBalanceBeforeRequests: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
        const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateStart: AccountingState = await fund.accounting.getState();

        // Approve front office to spend tokens to deposit
        const approveRequestDepositTxns = await Promise.all(
            users.map(
                async (user) =>
                    await (
                        await token.token.connect(user).approve(fund.frontOffice.address, ethers.utils.parseEther("1"))
                    ).wait()
            )
        );

        // Request deposits
        const requestDepositTxns = await Promise.all(
            users.map(
                async (user) =>
                    await (
                        await fund.frontOffice.connect(user).requestDeposit(
                            token.token.address,
                            ethers.utils.parseEther("1"), // amountIn
                            ethers.utils.parseEther("0"), // minAmountOut
                            1000, // blockDeadline
                            ethers.constants.AddressZero // incentiveAddress
                        )
                    ).wait()
            )
        );

        // Track states
        const usersTokenBalancesAfterRequests: BigNumber[] = await Promise.all(
            users.map(async (user) => await token.token.balanceOf(user.address))
        );
        const foTokenBalanceAfterRequests: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
        const usersFundTokenBalancesBeforeProcess: BigNumber[] = await Promise.all(
            users.map(async (user) => await fund.fundToken.balanceOf(user.address))
        );
        const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

        // Process deposit
        const processDepositsTxn = await (
            await fund.frontOffice.connect(fund.roles.taskRunner).processDeposits(token.token.address, users.length)
        ).wait();

        // Track states
        const usersFundTokenBalancesAfterProcess: BigNumber[] = await Promise.all(
            users.map(async (user) => await fund.fundToken.balanceOf(user.address))
        );
        const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();
        const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateEnd: AccountingState = await fund.accounting.getState();

        // Compute states
        usersTokensDeposited = usersTokenBalancesBeforeRequests.map((each, index) =>
            each.sub(usersTokenBalancesAfterRequests[index])
        );
        const usersTokensDepositedSum = usersTokensDeposited.reduce((a, b) => a.add(b), BigNumber.from(0));
        const foTokensDeposited = foTokenBalanceAfterRequests.sub(foTokenBalanceBeforeRequests);
        usersFundTokensReceived = usersFundTokenBalancesAfterProcess.map((each, index) =>
            each.sub(usersFundTokenBalancesBeforeProcess[index])
        );
        const usersFundTokensReceivedSum = usersFundTokensReceived.reduce((a, b) => a.add(b), BigNumber.from(0));
        const fundTokensMinted = fundTokenSupplyAfterProcess.sub(fundTokenSupplyBeforeProcess);
        const accAumIncrease = accStateEnd.aumValue.sub(accStateStart.aumValue);
        const accBeginningSupplyIncrease = accStateEnd.periodBeginningSupply.sub(accStateStart.periodBeginningSupply);
        const accTheoreticalSupplyIncrease = accStateEnd.theoreticalSupply.sub(accStateStart.theoreticalSupply);

        // Log states
        if (verbose) {
            console.log(`Users Tokens Deposited: ${usersTokensDeposited}`);
            console.log(`Users Tokens Deposited Sum: ${usersTokensDepositedSum}`);
            console.log(`Front Office Tokens Deposited: ${foTokensDeposited}`);
            console.log(`Users Fund Tokens Received: ${usersFundTokensReceived}`);
            console.log(`Users Fund Tokens Received Sum: ${usersFundTokensReceivedSum}`);
            console.log(`Fund Tokens Minted: ${fundTokensMinted}`);
            console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
            console.log(`Accounting AUM Increase: ${accAumIncrease}`);
            console.log(`Accounting Beginning Supply Increase ${accBeginningSupplyIncrease}`);
            console.log(`Accounting Theoretical Supply Increase ${accTheoreticalSupplyIncrease}`);
        }

        // Assert states
        helpers.assert(
            usersTokensDeposited.every((each) => !each.eq(0)),
            "not all deposits successful"
        );
        helpers.assert(usersTokensDepositedSum.eq(foTokensDeposited), "tokens deposited do not match");
        helpers.assert(usersFundTokensReceivedSum.eq(fundTokensMinted), "fund tokens received and minted do not match");
        // 50 wei of allowance for rounding errors in fund token price ($50e-18)
        helpers.assert(
            fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(50),
            "fund token price changed unexpectedly"
        );
        helpers.assert(accBeginningSupplyIncrease.eq(fundTokensMinted), "accounting beginning supply wrong");
        helpers.assert(accTheoreticalSupplyIncrease.eq(fundTokensMinted), "accounting theoretical supply wrong");

        // Log gas
        console.log(`Approve Request Deposit Gas Used: ${approveRequestDepositTxns.map((txn) => txn.gasUsed)}`);
        console.log(`Request Deposit Gas Used: ${requestDepositTxns.map((txn) => txn.gasUsed)}`);
        console.log(`Process Deposits Gas Used: ${helpers.formatGas(processDepositsTxn.gasUsed)}`);

        console.log(" --- bsc > interact > suite1 > multipleDepositsAndWithdrawals > deposits > done --- ");
    }
    // withdrawals
    {
        console.log(" --- bsc > interact > suite1 > multipleDepositsAndWithdrawals > withdrawals > start --- ");

        // Track states
        const usersFundTokenBalancesBeforeRequests: BigNumber[] = await Promise.all(
            users.map(async (user) => await fund.fundToken.balanceOf(user.address))
        );
        const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateStart: AccountingState = await fund.accounting.getState();

        // Approve front office to process withdrawal amount
        const approveFoWithdrawalsTxn = await (
            await fund.fund
                .connect(fund.roles.taskRunner)
                .approveFrontOfficeForWithdrawals(
                    [token.token.address],
                    [usersTokensDeposited.reduce((a, b) => a.add(b), BigNumber.from(0))]
                )
        ).wait();

        // Approve front office to spend fund tokens to withdraw
        const approveRequestWithdrawalTxns = await Promise.all(
            users.map(
                async (user, index) =>
                    await (
                        await fund.fundToken
                            .connect(user)
                            .approve(fund.frontOffice.address, usersFundTokensReceived[index])
                    ).wait()
            )
        );

        // Request withdrawals
        const requestWithdrawalTxns = await Promise.all(
            users.map(
                async (user, index) =>
                    await (
                        await fund.frontOffice.connect(user).requestWithdrawal(
                            token.token.address,
                            usersFundTokensReceived[index], // amountIn
                            ethers.utils.parseEther("0"), // minAmountOut
                            1000 // blockDeadline
                        )
                    ).wait()
            )
        );

        // Track states
        const usersFundTokenBalancesAfterRequests: BigNumber[] = await Promise.all(
            users.map(async (user) => await fund.fundToken.balanceOf(user.address))
        );
        const usersTokenBalancesBeforeProcess: BigNumber[] = await Promise.all(
            users.map(async (user) => await token.token.balanceOf(user.address))
        );
        const fundTokenBalanceBeforeProcess: BigNumber = await token.token.balanceOf(fund.fund.address);
        const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

        // Process withdrawals
        const processWithdrawalsTxn = await (
            await fund.frontOffice.connect(fund.roles.taskRunner).processWithdrawals(token.token.address, users.length)
        ).wait();

        // Track states
        const usersTokenBalancesAfterProcess: BigNumber[] = await Promise.all(
            users.map(async (user) => await token.token.balanceOf(user.address))
        );
        const fundTokenBalanceAfterProcess: BigNumber = await token.token.balanceOf(fund.fund.address);
        const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();
        const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateEnd: AccountingState = await fund.accounting.getState();

        // Compute states
        const usersFundTokensReturned = usersFundTokenBalancesBeforeRequests.map((each, index) =>
            each.sub(usersFundTokenBalancesAfterRequests[index])
        );
        const usersFundTokensReturnedSum = usersFundTokensReturned.reduce((a, b) => a.add(b), BigNumber.from(0));
        const usersTokensReceived = usersTokenBalancesAfterProcess.map((each, index) =>
            each.sub(usersTokenBalancesBeforeProcess[index])
        );
        const usersTokensReceivedSum = usersTokensReceived.reduce((a, b) => a.add(b), BigNumber.from(0));
        const fundTokensWithdrawed = fundTokenBalanceBeforeProcess.sub(fundTokenBalanceAfterProcess);
        const fundTokensBurned = fundTokenSupplyBeforeProcess.sub(fundTokenSupplyAfterProcess);
        const accAumDecrease = accStateStart.aumValue.sub(accStateEnd.aumValue);
        const accBeginningSupplyDecrease = accStateStart.periodBeginningSupply.sub(accStateEnd.periodBeginningSupply);
        const accTheoreticalSupplyDecrease = accStateStart.theoreticalSupply.sub(accStateEnd.theoreticalSupply);

        // Log states
        if (verbose) {
            console.log(`Users Fund Tokens Returned: ${usersFundTokensReturned}`);
            console.log(`Users Fund Tokens Returned Sum: ${usersFundTokensReturnedSum}`);
            console.log(`Users Tokens Received: ${usersTokensReceived}`);
            console.log(`Users Tokens Received Sum: ${usersTokensReceivedSum}`);
            console.log(`Fund's Tokens Withdrawed: ${fundTokensWithdrawed}`);
            console.log(`Fund Tokens Burned: ${fundTokensBurned}`);
            console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
            console.log(`Accounting AUM Decrease: ${accAumDecrease}`);
            console.log(`Accounting Beginning Supply Decrease ${accBeginningSupplyDecrease}`);
            console.log(`Accounting Theoretical Supply Decrease ${accTheoreticalSupplyDecrease}`);
        }

        // Assert states
        helpers.assert(
            usersFundTokensReturned.every((each) => !each.eq(0)),
            "not all withdrawals successful"
        );
        helpers.assert(usersFundTokensReturnedSum.eq(fundTokensBurned), "fund tokens returned and burned do not match");
        helpers.assert(usersTokensReceivedSum.eq(fundTokensWithdrawed), "tokens received do not match");
        // 50 wei of allowance for rounding errors in fund token price ($50e-18)
        helpers.assert(
            fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(50),
            "fund token price changed unexpectedly"
        );
        helpers.assert(accBeginningSupplyDecrease.eq(fundTokensBurned), "accounting beginning supply wrong");
        helpers.assert(accTheoreticalSupplyDecrease.eq(fundTokensBurned), "accounting theoretical supply wrong");

        // Log gas
        console.log(`Approve Front Office Withdrawals Gas Used: ${helpers.formatGas(approveFoWithdrawalsTxn.gasUsed)}`);
        console.log(`Approve Request Withdrawal Gas Used: ${approveRequestWithdrawalTxns.map((txn) => txn.gasUsed)}`);
        console.log(`Request Withdrawal Gas Used: ${requestWithdrawalTxns.map((txn) => txn.gasUsed)}`);
        console.log(`Process Withdarawals Gas Used: ${helpers.formatGas(processWithdrawalsTxn.gasUsed)}`);

        console.log(" --- bsc > interact > suite1 > multipleDepositsAndWithdrawals > withdrawals > done --- ");
    }
    console.log(" --- bsc > interact > suite1 > multipleDeposits > done --- ");
    console.log();
};

/** Regular deposit and then deposit received fund tokens into incentive contract */
const interactDepositIncentiveWithdraw = async (
    fund: MainFund,
    user: SignerWithAddress,
    token: Token,
    verbose: boolean
): Promise<void> => {
    console.log(" --- bsc > interact > suite1 > depositIncentiveWithdraw > start --- ");

    // States to be set by deposit and used in withdrawal
    let userTokensDeposited: BigNumber;
    let userFundTokensReceived: BigNumber;
    let userFundTokensDepositedIncentive: BigNumber;

    // deposit
    {
        console.log(" --- bsc > interact > suite1 > depositIncentiveWithdraw > deposit > start --- ");

        // Register referral
        const registerReferralIncentiveTxn = await (
            await fund.incentives.referral.connect(user).register(fund.roles.holders[0].address)
        ).wait();

        // Track states
        const userTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(user.address);
        const foTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
        const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateStart: AccountingState = await fund.accounting.getState();

        // Approve front office to spend tokens to deposit
        const approveRequestDepositTxn = await (
            await token.token.connect(user).approve(fund.frontOffice.address, ethers.utils.parseEther("1"))
        ).wait();

        // Request deposit
        const requestDepositTxn = await (
            await fund.frontOffice.connect(user).requestDeposit(
                token.token.address,
                ethers.utils.parseEther("1"), // amountIn
                ethers.utils.parseEther("0"), // minAmountOut
                1000, // blockDeadline
                ethers.constants.AddressZero // incentiveAddress
            )
        ).wait();

        // Track states
        const userTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(user.address);
        const foTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
        const userFundTokenBalanceBeforeProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
        const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

        // Process deposit
        const processDepositsTxn = await (
            await fund.frontOffice.connect(fund.roles.taskRunner).processDeposits(token.token.address, 10)
        ).wait();

        // Track states
        const userFundTokenBalanceAfterProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
        const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();
        const userFundTokensInIncentiveBefore: BigNumber = await fund.incentives.referral.getBalance(user.address);

        // Approve referral incentive contract to spend fund tokens
        const approveReferralIncentiveTxn = await (
            await fund.fundToken.connect(user).approve(fund.incentives.referral.address, ethers.utils.parseEther("1"))
        ).wait();

        // Deposit fund tokens into referral incentive contract
        const depositReferralIncentiveTxn = await (
            await fund.incentives.referral
                .connect(user)
                .deposit(userFundTokenBalanceAfterProcess.sub(userFundTokenBalanceBeforeProcess))
        ).wait();

        // Track states
        const userFundTokenBalanceAfterIncentive: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userFundTokensInIncentiveAfter: BigNumber = await fund.incentives.referral.getBalance(user.address);
        const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateEnd: AccountingState = await fund.accounting.getState();

        // Compute states
        userTokensDeposited = userTokenBalanceBeforeRequest.sub(userTokenBalanceAfterRequest);
        const foTokensDeposited = foTokenBalanceAfterRequest.sub(foTokenBalanceBeforeRequest);
        userFundTokensReceived = userFundTokenBalanceAfterProcess.sub(userFundTokenBalanceBeforeProcess);
        const fundTokensMinted = fundTokenSupplyAfterProcess.sub(fundTokenSupplyBeforeProcess);
        const userFundTokensDepositedBalance = userFundTokenBalanceAfterProcess.sub(userFundTokenBalanceAfterIncentive);
        userFundTokensDepositedIncentive = userFundTokensInIncentiveAfter.sub(userFundTokensInIncentiveBefore);
        const accAumIncrease = accStateEnd.aumValue.sub(accStateStart.aumValue);
        const accBeginningSupplyIncrease = accStateEnd.periodBeginningSupply.sub(accStateStart.periodBeginningSupply);
        const accTheoreticalSupplyIncrease = accStateEnd.theoreticalSupply.sub(accStateStart.theoreticalSupply);

        // Log states
        if (verbose) {
            console.log(`User Tokens Deposited: ${userTokensDeposited}`);
            console.log(`Front Office Tokens Deposited: ${foTokensDeposited}`);
            console.log(`User Fund Tokens Received: ${userFundTokensReceived}`);
            console.log(`Fund Tokens Minted: ${fundTokensMinted}`);
            console.log(`User Fund Tokens Deposited (Balance): ${userFundTokensDepositedBalance}`);
            console.log(`User Fund Tokens Deposited (Incentive): ${userFundTokensDepositedIncentive}`);
            console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
            console.log(`Accounting AUM Increase: ${accAumIncrease}`);
            console.log(`Accounting Beginning Supply Increase ${accBeginningSupplyIncrease}`);
            console.log(`Accounting Theoretical Supply Increase ${accTheoreticalSupplyIncrease}`);
        }

        // Assert states
        helpers.assert(userTokensDeposited.eq(foTokensDeposited), "tokens deposited do not match");
        helpers.assert(userFundTokensReceived.eq(fundTokensMinted), "fund tokens received and minted do not match");
        helpers.assert(
            userFundTokensDepositedBalance.eq(userFundTokensDepositedIncentive),
            "fund tokens deposited do not match"
        );
        // 5 wei of allowance for rounding errors in fund token price ($5e-18)
        helpers.assert(fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(5), "fund token price changed unexpectedly");
        helpers.assert(accBeginningSupplyIncrease.eq(fundTokensMinted), "accounting beginning supply wrong");
        helpers.assert(accTheoreticalSupplyIncrease.eq(fundTokensMinted), "accounting theoretical supply wrong");

        // Log gas
        console.log(`Register Referral Incentive Gas Used: ${helpers.formatGas(registerReferralIncentiveTxn.gasUsed)}`);
        console.log(`Approve Request Deposit Gas Used: ${helpers.formatGas(approveRequestDepositTxn.gasUsed)}`);
        console.log(`Request Deposit Gas Used: ${helpers.formatGas(requestDepositTxn.gasUsed)}`);
        console.log(`Process Deposits Gas Used: ${helpers.formatGas(processDepositsTxn.gasUsed)}`);
        console.log(`Approve Referral Incentive Gas Used: ${helpers.formatGas(approveReferralIncentiveTxn.gasUsed)}`);
        console.log(`Deposit Referral Incentive Gas Used: ${helpers.formatGas(depositReferralIncentiveTxn.gasUsed)}`);

        console.log(" --- bsc > interact > suite1 > depositIncentiveWithdraw > deposit > done --- ");
    }
    // withdrawal
    {
        console.log(" --- bsc > interact > suite1 > depositIncentiveWithdraw > withdrawal > start --- ");

        // Track states
        const userFundTokenBalanceBeforeIncentive: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userFundTokensInIncentiveBefore: BigNumber = await fund.incentives.referral.getBalance(user.address);
        const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateStart: AccountingState = await fund.accounting.getState();

        // Withdraw from incentive
        const withdrawReferralIncentiveTxn = await (
            await fund.incentives.referral.connect(user).withdraw(userFundTokensDepositedIncentive)
        ).wait();

        // Track states
        const userFundTokenBalanceAfterIncentive: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userFundTokensInIncentiveAfter: BigNumber = await fund.incentives.referral.getBalance(user.address);

        // Approve front office to process withdrawal amount
        const approveFoWithdrawalTxn = await (
            await fund.fund
                .connect(fund.roles.taskRunner)
                .approveFrontOfficeForWithdrawals([token.token.address], [userTokensDeposited])
        ).wait();

        // Approve front office to spend fund tokens to withdraw
        const approveRequestWithdrawalTxn = await (
            await fund.fundToken.connect(user).approve(fund.frontOffice.address, userFundTokensReceived)
        ).wait();

        // Request withdrawal
        const requestWithdrawalTxn = await (
            await fund.frontOffice.connect(user).requestWithdrawal(
                token.token.address,
                userFundTokensReceived, // amountIn
                ethers.utils.parseEther("0"), // minAmountOut
                1000 // blockDeadline
            )
        ).wait();

        // Track states
        const userFundTokenBalanceAfterRequest: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userTokenBalanceBeforeProcess: BigNumber = await token.token.balanceOf(user.address);
        const fundTokenBalanceBeforeProcess: BigNumber = await token.token.balanceOf(fund.fund.address);
        const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

        // Process withdrawal
        const processWithdrawalTxn = await (
            await fund.frontOffice.connect(fund.roles.taskRunner).processWithdrawals(token.token.address, 10)
        ).wait();

        // Track states
        const userTokenBalanceAfterProcess: BigNumber = await token.token.balanceOf(user.address);
        const fundTokenBalanceAfterProcess: BigNumber = await token.token.balanceOf(fund.fund.address);
        const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();
        const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateEnd: AccountingState = await fund.accounting.getState();

        // Compute states
        const userFundTokensWithdrawedIncentive = userFundTokensInIncentiveBefore.sub(userFundTokensInIncentiveAfter);
        const userFundTokensWithdrawedBalance = userFundTokenBalanceAfterIncentive.sub(
            userFundTokenBalanceBeforeIncentive
        );
        const userFundTokensReturned = userFundTokenBalanceAfterIncentive.sub(userFundTokenBalanceAfterRequest);
        const userTokensReceived = userTokenBalanceAfterProcess.sub(userTokenBalanceBeforeProcess);
        const fundTokensWithdrawed = fundTokenBalanceBeforeProcess.sub(fundTokenBalanceAfterProcess);
        const fundTokensBurned = fundTokenSupplyBeforeProcess.sub(fundTokenSupplyAfterProcess);
        const accAumDecrease = accStateStart.aumValue.sub(accStateEnd.aumValue);
        const accBeginningSupplyDecrease = accStateStart.periodBeginningSupply.sub(accStateEnd.periodBeginningSupply);
        const accTheoreticalSupplyDecrease = accStateStart.theoreticalSupply.sub(accStateEnd.theoreticalSupply);

        // Log states
        if (verbose) {
            console.log(`User Fund Tokens Withdrawed (Incentive Balance): ${userFundTokensWithdrawedIncentive}`);
            console.log(`User Fund Tokens Withdrawed (User Balance): ${userFundTokensWithdrawedBalance}`);
            console.log(`User Fund Tokens Returned: ${userFundTokensReturned}`);
            console.log(`User Tokens Received: ${userTokensReceived}`);
            console.log(`Fund's Tokens Withdrawed: ${fundTokensWithdrawed}`);
            console.log(`Fund Tokens Burned: ${fundTokensBurned}`);
            console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
            console.log(`Accounting AUM Decrease: ${accAumDecrease}`);
            console.log(`Accounting Beginning Supply Decrease ${accBeginningSupplyDecrease}`);
            console.log(`Accounting Theoretical Supply Decrease ${accTheoreticalSupplyDecrease}`);
        }

        // Assert states
        helpers.assert(
            userFundTokensWithdrawedIncentive.eq(userFundTokensWithdrawedBalance),
            "fund tokens withdrawed do not match"
        );
        helpers.assert(userFundTokensReturned.eq(fundTokensBurned), "fund tokens returned and burned do not match");
        helpers.assert(userTokensReceived.eq(fundTokensWithdrawed), "tokens received do not match");
        // 50 wei of allowance for rounding errors in fund token price ($50e-18)
        helpers.assert(
            fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(50),
            "fund token price changed unexpectedly"
        );
        helpers.assert(accBeginningSupplyDecrease.eq(fundTokensBurned), "accounting beginning supply wrong");
        helpers.assert(accTheoreticalSupplyDecrease.eq(fundTokensBurned), "accounting theoretical supply wrong");

        // Log gas
        console.log(`Withdraw From Incentive Gas Used: ${helpers.formatGas(withdrawReferralIncentiveTxn.gasUsed)}`);
        console.log(`Approve Front Office Withdrawal Gas Used: ${helpers.formatGas(approveFoWithdrawalTxn.gasUsed)}`);
        console.log(`Approve Request Withdrawal Gas Used: ${helpers.formatGas(approveRequestWithdrawalTxn.gasUsed)}`);
        console.log(`Request Withdrawal Gas Used: ${helpers.formatGas(requestWithdrawalTxn.gasUsed)}`);
        console.log(`Process Withdarawals Gas Used: ${helpers.formatGas(processWithdrawalTxn.gasUsed)}`);

        console.log(" --- bsc > interact > suite1 > depositIncentiveWithdraw > withdrawal > done --- ");
    }

    console.log(" --- bsc > interact > suite1 > depositIncentiveWithdraw > done --- ");
    console.log();
};

/** Direct deposit into incentive contract */
const interactDirectDepositIntoIncentive = async (
    fund: MainFund,
    user: SignerWithAddress,
    token: Token,
    verbose: boolean
): Promise<void> => {
    console.log(" --- bsc > interact > suite1 > directDepositIntoIncentive > start --- ");

    let userTokensDeposited: BigNumber;
    let userFundTokensInIncentive: BigNumber;

    // deposit
    {
        console.log(" --- bsc > interact > suite1 > directDepositIntoIncentive > deposit > start --- ");
        // Register referral
        const registerReferralIncentiveTxn = await (
            await fund.incentives.referral.connect(user).register(fund.roles.holders[0].address)
        ).wait();

        // Track states
        const userTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(user.address);
        const foTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
        const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateStart: AccountingState = await fund.accounting.getState();

        // Approve front office to spend tokens to deposit
        const approveRequestDepositTxn = await (
            await token.token.connect(user).approve(fund.frontOffice.address, ethers.utils.parseEther("1"))
        ).wait();

        // Request deposit
        const requestDepositTxn = await (
            await fund.frontOffice.connect(user).requestDeposit(
                token.token.address,
                ethers.utils.parseEther("1"), // amountIn
                ethers.utils.parseEther("0"), // minAmountOut
                1000, // blockDeadline
                fund.incentives.referral.address // incentiveAddress
            )
        ).wait();

        // Track states
        const userTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(user.address);
        const foTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
        const userFundTokenBalanceBeforeProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userFundTokensInIncentiveBeforeProcess: BigNumber = await fund.incentives.referral.getBalance(
            user.address
        );
        const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

        // Process deposit
        const processDepositsTxn = await (
            await fund.frontOffice.connect(fund.roles.taskRunner).processDeposits(token.token.address, 10)
        ).wait();

        // Track states
        const userFundTokenBalanceAfterProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userFundTokensInIncentiveAfterProcess: BigNumber = await fund.incentives.referral.getBalance(
            user.address
        );
        const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();
        const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateEnd: AccountingState = await fund.accounting.getState();

        // Compute states
        userTokensDeposited = userTokenBalanceBeforeRequest.sub(userTokenBalanceAfterRequest);
        const foTokensDeposited = foTokenBalanceAfterRequest.sub(foTokenBalanceBeforeRequest);
        const userFundTokensReceived = userFundTokenBalanceAfterProcess.sub(userFundTokenBalanceBeforeProcess);
        userFundTokensInIncentive = userFundTokensInIncentiveAfterProcess.sub(userFundTokensInIncentiveBeforeProcess);
        const fundTokensMinted = fundTokenSupplyAfterProcess.sub(fundTokenSupplyBeforeProcess);
        const accAumIncrease = accStateEnd.aumValue.sub(accStateStart.aumValue);
        const accBeginningSupplyIncrease = accStateEnd.periodBeginningSupply.sub(accStateStart.periodBeginningSupply);
        const accTheoreticalSupplyIncrease = accStateEnd.theoreticalSupply.sub(accStateStart.theoreticalSupply);

        // Log states
        if (verbose) {
            console.log(`User Tokens Deposited: ${userTokensDeposited}`);
            console.log(`Front Office Tokens Deposited: ${foTokensDeposited}`);
            console.log(`User Fund Tokens Received: ${userFundTokensReceived}`);
            console.log(`User Fund Tokens Received In Incentive Contract: ${userFundTokensInIncentive}`);
            console.log(`Fund Tokens Minted: ${fundTokensMinted}`);
            console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
            console.log(`Accounting AUM Increase: ${accAumIncrease}`);
            console.log(`Accounting Beginning Supply Increase ${accBeginningSupplyIncrease}`);
            console.log(`Accounting Theoretical Supply Increase ${accTheoreticalSupplyIncrease}`);
        }

        // Assert states
        helpers.assert(userTokensDeposited.eq(foTokensDeposited), "tokens deposited do not match");
        helpers.assert(userFundTokensReceived.eq(0), "user received fund tokens unexpectedly");
        helpers.assert(
            userFundTokensInIncentive.eq(fundTokensMinted),
            "fund tokens in incentive and minted do not match"
        );
        // 5 wei of allowance for rounding errors in fund token price ($5e-18)
        helpers.assert(fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(5), "fund token price changed unexpectedly");
        helpers.assert(accBeginningSupplyIncrease.eq(fundTokensMinted), "accounting beginning supply wrong");
        helpers.assert(accTheoreticalSupplyIncrease.eq(fundTokensMinted), "accounting theoretical supply wrong");

        // Log gas
        console.log(`Register Referral Incentive Gas Used: ${registerReferralIncentiveTxn.gasUsed}`);
        console.log(`Approve Request Deposit Gas Used: ${approveRequestDepositTxn.gasUsed}`);
        console.log(`Request Deposit Gas Used: ${requestDepositTxn.gasUsed}`);
        console.log(`Process Deposits Gas Used: ${processDepositsTxn.gasUsed}`);

        console.log(" --- bsc > interact > suite1 > directDepositIntoIncentive > deposit > done --- ");
    }
    // withdrawal
    {
        console.log(" --- bsc > interact > suite1 > directDepositIntoIncentive > withdrawal > start --- ");

        // Track states
        const userFundTokenBalanceBeforeIncentive: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userFundTokensInIncentiveBefore: BigNumber = await fund.incentives.referral.getBalance(user.address);
        const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateStart: AccountingState = await fund.accounting.getState();

        // Withdraw from incentive
        const withdrawReferralIncentiveTxn = await (
            await fund.incentives.referral.connect(user).withdraw(userFundTokensInIncentive)
        ).wait();

        // Track states
        const userFundTokenBalanceAfterIncentive: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userFundTokensInIncentiveAfter: BigNumber = await fund.incentives.referral.getBalance(user.address);

        // Approve front office to process withdrawal amount
        const approveFoWithdrawalTxn = await (
            await fund.fund
                .connect(fund.roles.taskRunner)
                .approveFrontOfficeForWithdrawals([token.token.address], [userTokensDeposited])
        ).wait();

        // Approve front office to spend fund tokens to withdraw
        const approveRequestWithdrawalTxn = await (
            await fund.fundToken.connect(user).approve(fund.frontOffice.address, userFundTokensInIncentive)
        ).wait();

        // Request withdrawal
        const requestWithdrawalTxn = await (
            await fund.frontOffice.connect(user).requestWithdrawal(
                token.token.address,
                userFundTokensInIncentive, // amountIn
                ethers.utils.parseEther("0"), // minAmountOut
                1000 // blockDeadline
            )
        ).wait();

        // Track states
        const userFundTokenBalanceAfterRequest: BigNumber = await fund.fundToken.balanceOf(user.address);
        const userTokenBalanceBeforeProcess: BigNumber = await token.token.balanceOf(user.address);
        const fundTokenBalanceBeforeProcess: BigNumber = await token.token.balanceOf(fund.fund.address);
        const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

        // Process withdrawal
        const processWithdrawalTxn = await (
            await fund.frontOffice.connect(fund.roles.taskRunner).processWithdrawals(token.token.address, 10)
        ).wait();

        // Track states
        const userTokenBalanceAfterProcess: BigNumber = await token.token.balanceOf(user.address);
        const fundTokenBalanceAfterProcess: BigNumber = await token.token.balanceOf(fund.fund.address);
        const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();
        const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
        const accStateEnd: AccountingState = await fund.accounting.getState();

        // Compute states
        const userFundTokensWithdrawedIncentive = userFundTokensInIncentiveBefore.sub(userFundTokensInIncentiveAfter);
        const userFundTokensWithdrawedBalance = userFundTokenBalanceAfterIncentive.sub(
            userFundTokenBalanceBeforeIncentive
        );
        const userFundTokensReturned = userFundTokenBalanceAfterIncentive.sub(userFundTokenBalanceAfterRequest);
        const userTokensReceived = userTokenBalanceAfterProcess.sub(userTokenBalanceBeforeProcess);
        const fundTokensWithdrawed = fundTokenBalanceBeforeProcess.sub(fundTokenBalanceAfterProcess);
        const fundTokensBurned = fundTokenSupplyBeforeProcess.sub(fundTokenSupplyAfterProcess);
        const accAumDecrease = accStateStart.aumValue.sub(accStateEnd.aumValue);
        const accBeginningSupplyDecrease = accStateStart.periodBeginningSupply.sub(accStateEnd.periodBeginningSupply);
        const accTheoreticalSupplyDecrease = accStateStart.theoreticalSupply.sub(accStateEnd.theoreticalSupply);

        // Log states
        if (verbose) {
            console.log(`User Fund Tokens Withdrawed (Incentive Balance): ${userFundTokensWithdrawedIncentive}`);
            console.log(`User Fund Tokens Withdrawed (User Balance): ${userFundTokensWithdrawedBalance}`);
            console.log(`User Fund Tokens Returned: ${userFundTokensReturned}`);
            console.log(`User Tokens Received: ${userTokensReceived}`);
            console.log(`Fund's Tokens Withdrawed: ${fundTokensWithdrawed}`);
            console.log(`Fund Tokens Burned: ${fundTokensBurned}`);
            console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
            console.log(`Accounting AUM Decrease: ${accAumDecrease}`);
            console.log(`Accounting Beginning Supply Decrease ${accBeginningSupplyDecrease}`);
            console.log(`Accounting Theoretical Supply Decrease ${accTheoreticalSupplyDecrease}`);
        }

        // Assert states
        helpers.assert(
            userFundTokensWithdrawedIncentive.eq(userFundTokensWithdrawedBalance),
            "fund tokens withdrawed do not match"
        );
        helpers.assert(userFundTokensReturned.eq(fundTokensBurned), "fund tokens returned and burned do not match");
        helpers.assert(userTokensReceived.eq(fundTokensWithdrawed), "tokens received do not match");
        // 50 wei of allowance for rounding errors in fund token price ($50e-18)
        helpers.assert(
            fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(50),
            "fund token price changed unexpectedly"
        );
        helpers.assert(accBeginningSupplyDecrease.eq(fundTokensBurned), "accounting beginning supply wrong");
        helpers.assert(accTheoreticalSupplyDecrease.eq(fundTokensBurned), "accounting theoretical supply wrong");

        // Log gas
        console.log(`Withdraw From Incentive Gas Used: ${helpers.formatGas(withdrawReferralIncentiveTxn.gasUsed)}`);
        console.log(`Approve Front Office Withdrawal Gas Used: ${helpers.formatGas(approveFoWithdrawalTxn.gasUsed)}`);
        console.log(`Approve Request Withdrawal Gas Used: ${helpers.formatGas(approveRequestWithdrawalTxn.gasUsed)}`);
        console.log(`Request Withdrawal Gas Used: ${helpers.formatGas(requestWithdrawalTxn.gasUsed)}`);
        console.log(`Process Withdarawals Gas Used: ${helpers.formatGas(processWithdrawalTxn.gasUsed)}`);

        console.log(" --- bsc > interact > suite1 > directDepositIntoIncentive > withdrawal > done --- ");
    }

    console.log(" --- bsc > interact > suite1 > directDepositIntoIncentive > done --- ");
    console.log();
};

/** Deposit request expired and reclaim the deposited tokens  */
const interactDepositExpiredAndReclaim = async (
    fund: MainFund,
    user: SignerWithAddress,
    token: Token,
    verbose: boolean
): Promise<void> => {
    console.log(" --- bsc > interact > suite1 > depositExpiredAndReclaim > start --- ");

    // Track states
    const userTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(user.address);
    const foTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
    const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
    const accStateStart: AccountingState = await fund.accounting.getState();

    // Approve front office to spend tokens to deposit
    const approveRequestDepositTxn = await (
        await token.token.connect(user).approve(fund.frontOffice.address, ethers.utils.parseEther("1"))
    ).wait();

    // Request deposit
    const requestDepositTxn = await (
        await fund.frontOffice.connect(user).requestDeposit(
            token.token.address,
            ethers.utils.parseEther("1"), // amountIn
            ethers.utils.parseEther("1"), // minAmountOut
            0, // blockDeadline (sure to be expired)
            ethers.constants.AddressZero // incentiveAddress
        )
    ).wait();

    // Track states
    const userTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(user.address);
    const foTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
    const userFundTokenBalanceBeforeProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
    const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

    // Process deposit
    const processDepositsTxn = await (
        await fund.frontOffice.connect(fund.roles.taskRunner).processDeposits(token.token.address, 10)
    ).wait();

    // Track states
    const userFundTokenBalanceAfterProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
    const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();

    // Reclaim
    // const reclaimFromFailedRequestTxn = await (
    //     await fund.frontOffice
    //         .connect(user)
    //         .reclaimFromFailedRequest((await fund.frontOffice.getUserRequestCount(user.address)) - 1)
    // ).wait();

    // Track states
    const userTokenBalanceAfterReclaim: BigNumber = await token.token.balanceOf(user.address);
    const foTokenBalanceAfterReclaim: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
    const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
    const accStateEnd: AccountingState = await fund.accounting.getState();

    // Compute states
    const userTokensDeposited = userTokenBalanceBeforeRequest.sub(userTokenBalanceAfterRequest);
    const foTokensDeposited = foTokenBalanceAfterRequest.sub(foTokenBalanceBeforeRequest);
    const userTokensReclaimed = userTokenBalanceAfterReclaim.sub(userTokenBalanceAfterRequest);
    const foTokensReclaimed = foTokenBalanceAfterRequest.sub(foTokenBalanceAfterReclaim);
    const userFundTokensReceived = userFundTokenBalanceAfterProcess.sub(userFundTokenBalanceBeforeProcess);
    const fundTokensMinted = fundTokenSupplyAfterProcess.sub(fundTokenSupplyBeforeProcess);
    const accAumIncrease = accStateEnd.aumValue.sub(accStateStart.aumValue);
    const accBeginningSupplyIncrease = accStateEnd.periodBeginningSupply.sub(accStateStart.periodBeginningSupply);
    const accTheoreticalSupplyIncrease = accStateEnd.theoreticalSupply.sub(accStateStart.theoreticalSupply);

    // Log states
    if (verbose) {
        console.log(`User Tokens Deposited: ${userTokensDeposited}`);
        console.log(`FrontOffice Tokens Deposited: ${foTokensDeposited}`);
        console.log(`User Tokens Reclaimed: ${userTokensReclaimed}`);
        console.log(`FrontOffice Tokens Reclaimed: ${foTokensReclaimed}`);
        console.log(`User Fund Tokens Received: ${userFundTokensReceived}`);
        console.log(`Fund Tokens Minted: ${fundTokensMinted}`);
        console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
        console.log(`Accounting AUM Increase: ${accAumIncrease}`);
        console.log(`Accounting Beginning Supply Increase ${accBeginningSupplyIncrease}`);
        console.log(`Accounting Theoretical Supply Increase ${accTheoreticalSupplyIncrease}`);
    }

    // Assert states
    helpers.assert(userTokensDeposited.eq(foTokensDeposited), "tokens deposited do not match");
    helpers.assert(userTokensReclaimed.eq(foTokensReclaimed), "tokens reclaimed do not match");
    helpers.assert(userFundTokensReceived.eq(fundTokensMinted), "fund tokens received and minted do not match");
    // 5 wei of allowance for rounding errors in fund token price ($5e-18)
    helpers.assert(fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(5), "fund token price changed unexpectedly");
    helpers.assert(accBeginningSupplyIncrease.eq(fundTokensMinted), "accounting beginning supply wrong");
    helpers.assert(accTheoreticalSupplyIncrease.eq(fundTokensMinted), "accounting theoretical supply wrong");

    // Log gas
    console.log(`Approve Request Deposit Gas Used: ${helpers.formatGas(approveRequestDepositTxn.gasUsed)}`);
    console.log(`Request Deposit Gas Used: ${helpers.formatGas(requestDepositTxn.gasUsed)}`);
    console.log(`Process Deposits Gas Used: ${helpers.formatGas(processDepositsTxn.gasUsed)}`);
    // console.log(`Reclaim From Failed Request Gas Used: ${helpers.formatGas(reclaimFromFailedRequestTxn.gasUsed)}`);

    console.log(" --- bsc > interact > suite1 > depositExpiredAndReclaim > done --- ");
    console.log();
};

/** Deposit request insufficient output and reclaim the deposited tokens  */
const interactDepositInsufficientOutputAndReclaim = async (
    fund: MainFund,
    user: SignerWithAddress,
    token: Token,
    verbose: boolean
): Promise<void> => {
    console.log(" --- bsc > interact > suite1 > depositInsufficientOutputAndReclaim > start --- ");

    // Track states
    const userTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(user.address);
    const foTokenBalanceBeforeRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
    const fundTokenPriceStart: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
    const accStateStart: AccountingState = await fund.accounting.getState();

    // Approve front office to spend tokens to deposit
    const approveRequestDepositTxn = await (
        await token.token.connect(user).approve(fund.frontOffice.address, ethers.utils.parseEther("1"))
    ).wait();

    // Request deposit
    const requestDepositTxn = await (
        await fund.frontOffice.connect(user).requestDeposit(
            token.token.address,
            ethers.utils.parseEther("1"), // amountIn
            ethers.utils.parseEther("1000"), // minAmountOut (sure to be insufficient)
            1000, // blockDeadline
            ethers.constants.AddressZero // incentiveAddress
        )
    ).wait();

    // Track states
    const userTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(user.address);
    const foTokenBalanceAfterRequest: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
    const userFundTokenBalanceBeforeProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
    const fundTokenSupplyBeforeProcess: BigNumber = await fund.fundToken.totalSupply();

    // Process deposit
    const processDepositsTxn = await (
        await fund.frontOffice.connect(fund.roles.taskRunner).processDeposits(token.token.address, 10)
    ).wait();

    // Track states
    const userFundTokenBalanceAfterProcess: BigNumber = await fund.fundToken.balanceOf(user.address);
    const fundTokenSupplyAfterProcess: BigNumber = await fund.fundToken.totalSupply();

    // Reclaim
    // const reclaimFromFailedRequestTxn = await (
    //     await fund.frontOffice
    //         .connect(user)
    //         .reclaimFromFailedRequest((await fund.frontOffice.getUserRequestCount(user.address)) - 1)
    // ).wait();

    // Track states
    const userTokenBalanceAfterReclaim: BigNumber = await token.token.balanceOf(user.address);
    const foTokenBalanceAfterReclaim: BigNumber = await token.token.balanceOf(fund.frontOffice.address);
    const fundTokenPriceEnd: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
    const accStateEnd: AccountingState = await fund.accounting.getState();

    // Compute states
    const userTokensDeposited = userTokenBalanceBeforeRequest.sub(userTokenBalanceAfterRequest);
    const foTokensDeposited = foTokenBalanceAfterRequest.sub(foTokenBalanceBeforeRequest);
    const userTokensReclaimed = userTokenBalanceAfterReclaim.sub(userTokenBalanceAfterRequest);
    const foTokensReclaimed = foTokenBalanceAfterRequest.sub(foTokenBalanceAfterReclaim);
    const userFundTokensReceived = userFundTokenBalanceAfterProcess.sub(userFundTokenBalanceBeforeProcess);
    const fundTokensMinted = fundTokenSupplyAfterProcess.sub(fundTokenSupplyBeforeProcess);
    const accAumIncrease = accStateEnd.aumValue.sub(accStateStart.aumValue);
    const accBeginningSupplyIncrease = accStateEnd.periodBeginningSupply.sub(accStateStart.periodBeginningSupply);
    const accTheoreticalSupplyIncrease = accStateEnd.theoreticalSupply.sub(accStateStart.theoreticalSupply);

    // Log states
    if (verbose) {
        console.log(`User Tokens Deposited: ${userTokensDeposited}`);
        console.log(`FrontOffice Tokens Deposited: ${foTokensDeposited}`);
        console.log(`User Tokens Reclaimed: ${userTokensReclaimed}`);
        console.log(`FrontOffice Tokens Reclaimed: ${foTokensReclaimed}`);
        console.log(`User Fund Tokens Received: ${userFundTokensReceived}`);
        console.log(`Fund Tokens Minted: ${fundTokensMinted}`);
        console.log(`Fund Token Prices: ${fundTokenPriceStart} --> ${fundTokenPriceEnd}`);
        console.log(`Accounting AUM Increase: ${accAumIncrease}`);
        console.log(`Accounting Beginning Supply Increase ${accBeginningSupplyIncrease}`);
        console.log(`Accounting Theoretical Supply Increase ${accTheoreticalSupplyIncrease}`);
    }

    // Assert states
    helpers.assert(userTokensDeposited.eq(foTokensDeposited), "tokens deposited do not match");
    helpers.assert(userTokensReclaimed.eq(foTokensReclaimed), "tokens reclaimed do not match");
    helpers.assert(userFundTokensReceived.eq(fundTokensMinted), "fund tokens received and minted do not match");
    // 5 wei of allowance for rounding errors in fund token price ($5e-18)
    helpers.assert(fundTokenPriceEnd.sub(fundTokenPriceStart).abs().lt(5), "fund token price changed unexpectedly");
    helpers.assert(accBeginningSupplyIncrease.eq(fundTokensMinted), "accounting beginning supply wrong");
    helpers.assert(accTheoreticalSupplyIncrease.eq(fundTokensMinted), "accounting theoretical supply wrong");

    // Log gas
    console.log(`Approve Request Deposit Gas Used: ${helpers.formatGas(approveRequestDepositTxn.gasUsed)}`);
    console.log(`Request Deposit Gas Used: ${helpers.formatGas(requestDepositTxn.gasUsed)}`);
    console.log(`Process Deposits Gas Used: ${helpers.formatGas(processDepositsTxn.gasUsed)}`);
    // console.log(`Reclaim From Failed Request Gas Used: ${helpers.formatGas(reclaimFromFailedRequestTxn.gasUsed)}`);

    console.log(" --- bsc > interact > suite1 > depositInsufficientOutputAndReclaim > done --- ");
    console.log();
};

/** Interact with the main fund */
export default async (state: ContractsState, verbose = false): Promise<void> => {
    if (!state.tokens) return;
    if (!state.mainFund) return;

    console.log(" --- bsc > interact > suite1 > start --- ");

    await interactMultipleDepositsAndWithdrawals(state.mainFund, state.signers, state.tokens[0], verbose);
    await interactDepositIncentiveWithdraw(state.mainFund, state.mainFund.roles.holders[1], state.tokens[1], verbose);
    await interactDirectDepositIntoIncentive(state.mainFund, state.mainFund.roles.holders[2], state.tokens[2], verbose);
    await interactDepositExpiredAndReclaim(state.mainFund, state.mainFund.roles.holders[1], state.tokens[1], verbose);
    await interactDepositInsufficientOutputAndReclaim(
        state.mainFund,
        state.mainFund.roles.holders[1],
        state.tokens[1],
        verbose
    );

    console.log(" --- bsc > interact > suite1 > done --- ");
};
