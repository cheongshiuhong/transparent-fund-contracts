/**
 * Interactions Suite 2 Script for the Main Fund.
 *
 * Integration tests a long sequence of transactions
 * in deposits and withdrawals, and AUM recording
 * to test that the long-running states are stable.
 */

// Types
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Contract } from "ethers";
import type { ContractsState, MainFund, Token, AccountingState } from "../interfaces";

// Library
import { ethers } from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";

// Code
import helpers from "../helpers";

/** Helper to deposit */
const deposit = async (
    fund: MainFund,
    user: SignerWithAddress,
    token: Token,
    amount: BigNumber,
    verbose: boolean
): Promise<BigNumber> => {
    if (verbose) console.log(`Depositing ${amount} of ${await token.token.symbol()}`);

    // Approve front office to spend token
    await (await token.token.connect(user).approve(fund.frontOffice.address, amount)).wait();

    // Request deposit
    await (
        await fund.frontOffice
            .connect(user)
            .requestDeposit(
                token.token.address,
                amount,
                ethers.utils.parseEther("0"),
                1000,
                ethers.constants.AddressZero
            )
    ).wait();

    // Process deposit
    const userFundTokenBalanceBeforeProcess = await fund.fundToken.balanceOf(user.address);
    await (await fund.frontOffice.connect(fund.roles.taskRunner).processDeposits(token.token.address, 1)).wait();
    const userFundTokenBalanceAfterProcess = await fund.fundToken.balanceOf(user.address);

    return userFundTokenBalanceAfterProcess.sub(userFundTokenBalanceBeforeProcess);
};

/** Helper to deposit directly into incentive */
const directDepositIntoIncentive = async (
    fund: MainFund,
    user: SignerWithAddress,
    token: Token,
    amount: BigNumber,
    incentive: Contract,
    verbose: boolean
): Promise<BigNumber> => {
    if (verbose) console.log(`Depositing ${amount} of ${await token.token.symbol()}`);

    // Approve front office to spend token
    await (await token.token.connect(user).approve(fund.frontOffice.address, amount)).wait();

    // Request deposit
    await (
        await fund.frontOffice
            .connect(user)
            .requestDeposit(token.token.address, amount, ethers.utils.parseEther("0"), 1000, incentive.address)
    ).wait();

    // Process deposit
    const userFundTokenInIncentiveBeforeProcess = await incentive.getBalance(user.address);
    await (await fund.frontOffice.connect(fund.roles.taskRunner).processDeposits(token.token.address, 1)).wait();
    const userFundTokenInIncentiveAfterProcess = await incentive.getBalance(user.address);

    return userFundTokenInIncentiveAfterProcess.sub(userFundTokenInIncentiveBeforeProcess);
};

/** Helper to withdraw */
const withdraw = async (
    fund: MainFund,
    user: SignerWithAddress,
    token: Token,
    amount: BigNumber,
    verbose: boolean
): Promise<BigNumber> => {
    if (verbose) console.log(`Withdrawing ${amount} Fund Tokens for ${await token.token.symbol()}`);

    // Approve front office to spend fund's token
    await (
        await fund.fund
            .connect(fund.roles.taskRunner)
            .approveFrontOfficeForWithdrawals([token.token.address], [ethers.utils.parseEther("100")])
    ).wait();

    // Approve front office to spend fund token
    await (await fund.fundToken.connect(user).approve(fund.frontOffice.address, amount)).wait();

    // Request withdrawal
    await (
        await fund.frontOffice
            .connect(user)
            .requestWithdrawal(token.token.address, amount, ethers.utils.parseEther("0"), 1000)
    ).wait();

    // Process withdrawal
    const userTokenBalanceBeforeProcess = await token.token.balanceOf(user.address);
    await (await fund.frontOffice.connect(fund.roles.taskRunner).processWithdrawals(token.token.address, 1)).wait();
    const userTokenBalanceAfterProcess = await token.token.balanceOf(user.address);

    // Reset fund's front office allowance to 0
    await (
        await fund.fund
            .connect(fund.roles.taskRunner)
            .approveFrontOfficeForWithdrawals([token.token.address], [ethers.utils.parseEther("0")])
    ).wait();

    return userTokenBalanceAfterProcess.sub(userTokenBalanceBeforeProcess);
};

/** Helper to record aum value */
const recordAumValue = async (fund: MainFund, value: BigNumber, verbose: boolean): Promise<void> => {
    if (verbose) console.log(`Recording AUM Value to ${value}`);

    const response = await (await fund.accounting.connect(fund.roles.taskRunner).recordAumValue(value)).wait();

    const isEvaluationPeriodReset = response.logs.some(
        (log: { topics: string[] }) =>
            log.topics[0] === ethers.utils.keccak256(ethers.utils.toUtf8Bytes("EvaluationPeriodStart"))
    );

    if (verbose && isEvaluationPeriodReset) {
        console.log("Evaluation Period Reset");
    }
};

/** The state return type */
type State = {
    price: BigNumber;
    aumValue: BigNumber;
    theoreticalSupply: BigNumber;
    actualSupply: BigNumber;
    accountingBalance: BigNumber;
    caoBalance: BigNumber;
};

/** Gets the state and logs it if verbose is on */
const getState = async (fund: MainFund, verbose: boolean, prevState?: State): Promise<State> => {
    const price: BigNumber = (await fund.accounting.getFundTokenPrice())[0];
    const { aumValue, theoreticalSupply, periodBeginningBlock }: AccountingState = await fund.accounting.getState();
    const actualSupply: BigNumber = await fund.fundToken.totalSupply();
    const accountingBalance: BigNumber = await fund.fundToken.balanceOf(fund.accounting.address);
    const caoBalance: BigNumber = await fund.fundToken.balanceOf(fund.cao.address);

    if (verbose) {
        let aumValueLog = `AUM: ${aumValue}`;
        let theoreticalSupplyLog = `Theoretical Supply: ${theoreticalSupply}`;
        let actualSupplyLog = `Actual Supply ${actualSupply}`;

        // Add the change suffixes if previous state was passed in
        if (prevState) {
            const scale = BigNumber.from(10000);
            const denom = scale.div(100).toNumber();

            const aumPctChange = aumValue.mul(scale).div(prevState.aumValue).sub(scale).toNumber() / denom;
            aumValueLog += ` (${aumPctChange.toFixed(2)}% Δ)`;

            const theoreticalSupplyChange =
                theoreticalSupply.mul(scale).div(prevState.theoreticalSupply).sub(scale).toNumber() / denom;
            theoreticalSupplyLog += ` (${theoreticalSupplyChange.toFixed(2)}% Δ)`;

            const actualSupplyChange =
                actualSupply.mul(scale).div(prevState.actualSupply).sub(scale).toNumber() / denom;
            actualSupplyLog += ` (${actualSupplyChange.toFixed(2)}% Δ)`;
        }

        const fundTokenPrice = price.div(BigNumber.from(10).pow(14)).toNumber() / 10000;

        console.log("--------------------------------------------------------");
        console.log(`State periodBeginningBlock=${periodBeginningBlock} currentBlock=${await helpers.getBlock()}:`);
        console.log(`Fund Token Price: ${fundTokenPrice.toFixed(4)}`);
        console.log(aumValueLog);
        console.log(theoreticalSupplyLog);
        console.log(actualSupplyLog);
        console.log(`Accounting Balance: ${accountingBalance}`);
        console.log(`CAO Balance: ${caoBalance}`);
        console.log("--------------------------------------------------------");
    }

    return { price, aumValue, theoreticalSupply, actualSupply, accountingBalance, caoBalance };
};

/** Performs a series of deposits/withdrwals amidst aum recording */
const interactBulk = async (
    fund: MainFund,
    users: SignerWithAddress[],
    tokens: Token[],
    verbose: boolean
): Promise<void> => {
    console.log(" --- bsc > interact > suite2 > bulk > start ---  ");

    // make collapsible for IDE
    {
        // Initial state
        const state0 = await getState(fund, verbose);

        // Op 1 - Record a 100% profit
        console.log("Op 1");
        await recordAumValue(fund, ethers.utils.parseEther("2"), verbose);
        const state1 = await getState(fund, verbose, state0);
        helpers.assert(state1.caoBalance.gt(state0.caoBalance), "cao did not get rewarded for profit");
        helpers.assert(state1.accountingBalance.eq(0), "accounting has residual balance");
        // Evaluation period reset

        // Op 2 - Record a 50% profit
        console.log("Op 2");
        await recordAumValue(fund, ethers.utils.parseEther("3"), verbose);
        const state2 = await getState(fund, verbose, state1);
        helpers.assert(state2.caoBalance.eq(state1.caoBalance), "cao got rewarded before evaluation period reset");
        helpers.assert(state2.accountingBalance.gt(0), "accounting did not get tokens on profit");

        // Op 3 - Deposit 1/3 worth of AUM
        console.log("Op 3");
        const ft1 = await deposit(fund, users[1], tokens[1], ethers.utils.parseEther("1"), verbose);
        const state3 = await getState(fund, verbose, state2);
        helpers.assert(state3.price.sub(state2.price).abs().lt(50), "fund token price changed unexpectedly");

        // Op 4 - Record a 50% loss
        console.log("Op 4");
        await recordAumValue(fund, ethers.utils.parseEther("2"), verbose);
        const state4 = await getState(fund, verbose, state3);
        helpers.assert(state4.caoBalance.eq(state3.caoBalance), "cao got rewarded for loss unexpectedly");
        helpers.assert(state4.accountingBalance.eq(0), "accounting has residual balance");
        // Evaluation period reset

        // Op 5 - Record a 100% profit
        console.log("Op 5");
        await recordAumValue(fund, ethers.utils.parseEther("4"), verbose);
        const state5 = await getState(fund, verbose, state4);
        helpers.assert(state5.caoBalance.eq(state4.caoBalance), "cao got rewarded before evaluation period reset");
        helpers.assert(state5.accountingBalance.gt(0), "accounting did not get tokens on profit");

        // Op 6 - Deposit 1/4 worth of AUM
        console.log("Op 6");
        const ft2 = await deposit(fund, users[2], tokens[2], ethers.utils.parseEther("1"), verbose);
        const state6 = await getState(fund, verbose, state5);
        helpers.assert(state6.price.sub(state5.price).abs().lt(50), "fund token price changed unexpectedly");

        // Op 7 - Record a 20% loss (period still positive)
        console.log("Op 7");
        await recordAumValue(fund, ethers.utils.parseEther("4"), verbose);
        const state7 = await getState(fund, verbose, state6);
        helpers.assert(state7.caoBalance.gt(state6.caoBalance), "cao did not get rewarded for profit");
        helpers.assert(state7.accountingBalance.eq(0), "accounting has residual balance");
        // Evaluation period reset

        // Op 8 - Withdraw the fund tokens deposited in the first deposit
        console.log("Op 8");
        await withdraw(fund, users[1], tokens[1], ft1, verbose);
        const state8 = await getState(fund, verbose, state7);
        helpers.assert(state8.price.sub(state7.price).abs().lt(50), "fund token price changed unexpectedly");

        // Op 9 - Withdraw the fund tokens deposited in the first deposit
        console.log("Op 9");
        await withdraw(fund, users[2], tokens[2], ft2, verbose);
        const state9 = await getState(fund, verbose, state8);
        helpers.assert(state9.price.sub(state8.price).abs().lt(50), "fund token price changed unexpectedly");

        // Op 9 - Record profit again after withdrawals
        console.log("Op 10");
        await recordAumValue(fund, ethers.utils.parseEther("5"), verbose);
        const state10 = await getState(fund, verbose, state9);
        helpers.assert(state10.caoBalance.gt(state9.caoBalance), "cao did not get rewarded for profit");
        helpers.assert(state10.accountingBalance.eq(0), "accounting has residual balance");
        // Evaluation period reset
    }

    console.log(" --- bsc > interact > suite2 > bulk > done ---  ");
};

/** Performs a series of deposits/withdrwals amidst aum recording with incentive */
const interactBulkWithIncentive = async (
    fund: MainFund,
    user: SignerWithAddress,
    referrer: SignerWithAddress,
    token: Token,
    verbose: boolean
): Promise<void> => {
    console.log(" --- bsc > interact > suite2 > bulkWithIncentive > start ---  ");

    // make collapsible for IDE
    {
        // Initial state
        const state0 = await getState(fund, verbose);

        // Setup - Register the user for the incentive
        await (await fund.incentives.referral.connect(user).register(referrer.address)).wait();

        // Op 1 - Deposit into incentive
        console.log("Op 1");
        await directDepositIntoIncentive(
            fund,
            user,
            token,
            ethers.utils.parseEther("1"),
            fund.incentives.referral,
            verbose
        );
        const state1 = await getState(fund, verbose);
        helpers.assert(state1.price.sub(state0.price).abs().lt(50), "fund token price changed unexpectedly");
        const userIncentiveBalance1 = await fund.incentives.referral.getBalance(user.address);

        // Op 2 - Record a profit
        console.log("Op 2");
        await recordAumValue(fund, state1.aumValue.mul(2), verbose);
        const state2 = await getState(fund, verbose);
        helpers.assert(state2.caoBalance.gt(state1.caoBalance), "cao did not get rewarded for profit");
        const userIncentiveBalance2 = await fund.incentives.referral.getBalance(user.address);
        helpers.assert(userIncentiveBalance2.gt(userIncentiveBalance1), "user did not get incentive on profit");
        // Evaluation period reset
    }

    console.log(" --- bsc > interact > suite2 > bulkWithIncentive > done ---  ");
};

/** Interact with the main fund */
export default async (state: ContractsState, verbose = false): Promise<void> => {
    if (!state.tokens) return;
    if (!state.mainFund) return;

    console.log(" --- bsc > interact > suite2 > start --- ");

    await interactBulk(state.mainFund, state.signers, state.tokens, verbose);
    await interactBulkWithIncentive(state.mainFund, state.signers[10], state.signers[11], state.tokens[1], verbose);

    console.log(" --- bsc > interact > suite2 > done --- ");
};
