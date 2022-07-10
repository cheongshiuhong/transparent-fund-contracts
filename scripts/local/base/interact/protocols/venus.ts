/**
 * Interactions with the Venus Protocol for the Base Fund.
 *
 * Integration tests the transactions with the Venus Protocol
 * where the absence of reverts/errors indicates that it works.
 */

// Types
import type { Contract } from "ethers";
import type { ContractsState, Token, VenusProtocols } from "../../interfaces";

// Library
import { ethers } from "hardhat";

// Code
import helpers from "../../helpers";

/** Enter markets on venus to enable collaterals */
const enterMarkets = async (fund: Contract, venus: VenusProtocols) => {
    console.log(" --- bsc > interact > venus > enableMarkets > start --- ");
    const poolAddresses = venus.lendingPools.map((poolDetails) => poolDetails.pool.address);
    const enterMarketsCallData = venus.comptrollerG5.interface.encodeFunctionData("enterMarkets", [poolAddresses]);
    const args = [1, venus.comptrollerG5.address, enterMarketsCallData, 0];
    const txn = await (await fund.call(args)).wait();

    console.log("Entered markets");
    console.log(`Gas used: ${txn.gasUsed}`);
    console.log(" --- bsc > interact > venus > enableMarkets > done --- ");
};

/** Supply eth on venus */
const interactSupplyEth = async (fund: Contract, venus: VenusProtocols) => {
    console.log(" --- bsc > interact > venus > supplyEth > start --- ");
    // supply ETH
    {
        console.log(" --- bsc > interact > venus > supplyEth > supplyEth > start --- ");
        const pool = venus.lendingPools[0].pool;
        const amount = ethers.utils.parseEther("10");
        const mintCallData = pool.interface.encodeFunctionData("mint");
        const args = [1, pool.address, mintCallData, amount];
        const txn = await (await fund.call(args)).wait();
        const balance = await pool.balanceOf(fund.address);

        console.log(`Supplied ${amount} ETH and got ${balance} VTokens`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > supplyEth > supplyEth > done --- ");
    }
    // redeem ETH
    {
        console.log(" --- bsc > interact > venus > supplyEth > redeemEth > start --- ");
        const pool = venus.lendingPools[0].pool;
        const vTokensBalanceBefore = await pool.balanceOf(fund.address);
        const ethBalanceBefore = await helpers.getEthBalance(fund);
        const redeemCallData = pool.interface.encodeFunctionData("redeem", [vTokensBalanceBefore]);
        const args = [1, pool.address, redeemCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const amountVTokensReturned = vTokensBalanceBefore.sub(await pool.balanceOf(fund.address));
        const amountEthRedeemed = (await helpers.getEthBalance(fund)).sub(ethBalanceBefore);
        const balance = await pool.balanceOf(fund.address);

        console.log(
            `Redeemed ${amountEthRedeemed} ETH for ${amountVTokensReturned} VTokens and left with ${balance} VTokens`
        );
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > supplyEth > redeemEth > done --- ");
    }
    console.log(" --- bsc > interact > venus > supplyEth > done --- ");
};

/** Supply tokens on venus */
const interactSupplyTokens = async (fund: Contract, tokens: Token[], venus: VenusProtocols) => {
    console.log(" --- bsc > interact > venus > supplyTokens > start --- ");
    // supply token
    {
        console.log(" --- bsc > interact > venus > supplyTokens > supplyToken > start --- ");
        const token = tokens[1].token;
        const pool = venus.lendingPools[1].pool;
        const amount = ethers.utils.parseEther("100");
        const approveCallData = token.interface.encodeFunctionData("approve", [pool.address, amount]);
        const mintCallData = pool.interface.encodeFunctionData("mint", [amount]);
        const args = [
            [0, token.address, approveCallData, 0],
            [1, pool.address, mintCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();
        const balance = await pool.balanceOf(fund.address);

        console.log(`Supplied ${amount} Token 1 and got ${balance} VTokens`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > supplyTokens > supplyToken > done --- ");
    }
    // redeem token
    {
        console.log(" --- bsc > interact > venus > supplyTokens > redeemToken > start --- ");
        const token = tokens[1].token;
        const tokenBalanceBefore = await token.balanceOf(fund.address);
        const pool = venus.lendingPools[1].pool;
        const amount = ethers.utils.parseEther("1");
        const redeemCallData = pool.interface.encodeFunctionData("redeem", [amount]);
        const args = [1, pool.address, redeemCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const tokenRedeemed = (await token.balanceOf(fund.address)).sub(tokenBalanceBefore);
        const balance = await pool.balanceOf(fund.address);

        console.log(`Redeemed ${tokenRedeemed} Token 1 for ${amount} VTokens and left with ${balance} VTokens`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > supplyTokens > redeemToken > done --- ");
    }
    console.log(" --- bsc > interact > venus > supplyTokens > done --- ");
};

/** Borrow eth on venus */
const interactBorrowEth = async (fund: Contract, venus: VenusProtocols) => {
    // borrow eth
    console.log(" --- bsc > interact > venus > borrowEth > start --- ");
    {
        console.log(" --- bsc > interact > venus > borrowEth > borrowEth > start --- ");
        const pool = venus.lendingPools[0].pool;
        const ethBalanceBefore = await helpers.getEthBalance(fund);
        const amount = ethers.utils.parseEther("1");
        const borrowCallData = pool.interface.encodeFunctionData("borrow", [amount]);
        const args = [1, pool.address, borrowCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const amountBorrowed = (await helpers.getEthBalance(fund)).sub(ethBalanceBefore);

        console.log(`Borrowed ${amountBorrowed} ETH`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > borrowEth > borrowEth > done --- ");
    }
    // repay eth
    {
        console.log(" --- bsc > interact > venus > borrowEth > repayEth > start  --- ");
        const pool = venus.lendingPools[0].pool;
        const ethBalanceBefore = await helpers.getEthBalance(fund);
        const amount = ethers.utils.parseEther("1");
        const repayCallData = pool.interface.encodeFunctionData("repayBorrow");
        const args = [1, pool.address, repayCallData, amount];
        const txn = await (await fund.call(args)).wait();
        const amountRepaid = ethBalanceBefore.sub(await helpers.getEthBalance(fund));

        console.log(`Repaid ${amountRepaid} ETH`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > borrowEth > repayEth > done  --- ");
    }
    console.log(" --- bsc > interact > venus > borrowEth > done --- ");
};

/** Borrow tokens on venus */
const interactBorrowTokens = async (fund: Contract, tokens: Token[], venus: VenusProtocols) => {
    console.log(" --- bsc > interact > venus > borrowTokens > start --- ");
    // borrow token
    {
        console.log(" --- bsc > interact > venus > borrowTokens > borrowToken > start --- ");
        const token = tokens[2].token;
        const pool = venus.lendingPools[2].pool;
        const tokenBalanceBefore = await token.balanceOf(fund.address);
        const amount = ethers.utils.parseEther("1");
        const borrowCallData = pool.interface.encodeFunctionData("borrow", [amount]);
        const args = [1, pool.address, borrowCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const amountBorrowed = (await token.balanceOf(fund.address)).sub(tokenBalanceBefore);

        console.log(`Borrowed ${amountBorrowed} Token 2`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > borrowTokens > borrowToken > done --- ");
    }
    // repay token
    {
        console.log(" --- bsc > interact > venus > borrowTokens > repayToken > start --- ");
        const token = tokens[2].token;
        const pool = venus.lendingPools[2].pool;
        const tokenBalanceBefore = await token.balanceOf(fund.address);
        const amount = ethers.utils.parseEther("1");
        const approveCallData = token.interface.encodeFunctionData("approve", [pool.address, amount]);
        const repayCallData = pool.interface.encodeFunctionData("repayBorrow", [amount]);
        const args = [
            [0, token.address, approveCallData, 0],
            [1, pool.address, repayCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();
        const amountRepaid = tokenBalanceBefore.sub(await token.balanceOf(fund.address));

        console.log(`Repaid ${amountRepaid} Token 2`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > venus > borrowTokens > repayToken --- ");
    }
    console.log(" --- bsc > interact > venus > borrowTokens > done --- ");
};

/** Interact with the venus protocol */
export default async (state: ContractsState): Promise<void> => {
    if (!state.tokens) return;
    if (!state.baseFund) return;
    if (!state.protocols?.venus) return;

    console.log(" --- bsc > interact > venus > start --- ");

    const operatorConnectedFund = state.baseFund.fund.connect(state.baseFund.roles.operators[0]);
    await enterMarkets(operatorConnectedFund, state.protocols.venus);
    await interactSupplyEth(operatorConnectedFund, state.protocols.venus);
    await interactSupplyTokens(operatorConnectedFund, state.tokens, state.protocols.venus);
    await interactBorrowEth(operatorConnectedFund, state.protocols.venus);
    await interactBorrowTokens(operatorConnectedFund, state.tokens, state.protocols.venus);

    console.log(" --- bsc > interact > venus > done --- ");
};
