/**
 * Interactions with the Pancakeswap Protocol for the Base Fund.
 *
 * Integration tests the transactions with the Pancakeswap Protocol
 * where the absence of reverts/errors indicates that it works.
 */

// Types
import type { Contract } from "ethers";
import type { ContractsState, Token, PancakeswapProtocols } from "../../interfaces";

// Library
import { ethers } from "hardhat";

// Code
import helpers from "../../helpers";

/** Swap assets on pancakeswap */
const interactSwaps = async (fund: Contract, tokens: Token[], pancakeswap: PancakeswapProtocols) => {
    console.log(" --- bsc > interact > pancakeswap > swaps > start --- ");
    // SwapExactETHForTokens
    {
        console.log(" --- bsc > interact > pancakeswap > swaps > swapExactETHForTokens > start --- ");
        const swapCallData = pancakeswap.router.interface.encodeFunctionData("swapExactETHForTokens", [
            0, // no minimum output
            [tokens[0].token.address, tokens[1].token.address],
            fund.address,
            await helpers.getBlockTimestampWithDelay(100),
        ]);
        console.log("SwapCallData", swapCallData);
        const amount = ethers.utils.parseEther("15");
        const args = [1, pancakeswap.router.address, swapCallData, amount];
        const txn = await (await fund.call(args)).wait();
        const balance = await tokens[1].token.balanceOf(fund.address);

        console.log(`Swapped ${amount} ETH for ${balance} token 1`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > swaps > swapExactETHForTokens > done --- ");
    }
    // SwapETHForExactTokens
    {
        console.log(" --- bsc > interact > pancakeswap > swaps > swapETHForExactTokens > start --- ");
        const amountIn = ethers.utils.parseEther("2");
        const amountOut = ethers.utils.parseEther("1");
        const swapCallData = pancakeswap.router.interface.encodeFunctionData("swapETHForExactTokens", [
            amountOut, // amount output
            [tokens[0].token.address, tokens[1].token.address],
            fund.address,
            await helpers.getBlockTimestampWithDelay(100),
        ]);
        const args = [1, pancakeswap.router.address, swapCallData, amountIn];
        const txn = await (await fund.call(args)).wait();
        const balance = await tokens[1].token.balanceOf(fund.address);

        console.log(`Swapped ${amountIn} ETH for ${balance} token 1`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > swaps > swapETHForExactTokens > done --- ");
    }
    // SwapExactTokensForTokens
    {
        console.log(" --- bsc > interact > pancakeswap > swaps > swapExactTokensForTokens > start --- ");
        const amount = ethers.utils.parseEther("10");
        const approveCallData = tokens[1].token.interface.encodeFunctionData("approve", [
            pancakeswap.router.address,
            amount,
        ]);
        const swapCallData = pancakeswap.router.interface.encodeFunctionData("swapExactTokensForTokens", [
            amount,
            0, // no minimum output
            [tokens[1].token.address, tokens[2].token.address],
            fund.address,
            await helpers.getBlockTimestampWithDelay(100),
        ]);
        const args = [
            [0, tokens[1].token.address, approveCallData, 0],
            [1, pancakeswap.router.address, swapCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();
        const balance = await tokens[2].token.balanceOf(fund.address);

        console.log(`Swapped ${amount} token 1 for ${balance} token 2`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > swaps > swapExactTokensForTokens > done --- ");
    }
    // SwapTokensForExactTokens
    {
        console.log(" --- bsc > interact > pancakeswap > swaps > SwapTokensForExactTokens > start --- ");
        const amountOut = ethers.utils.parseEther("4.5");
        const amountInMax = ethers.utils.parseEther("5");
        const approveCallData = tokens[2].token.interface.encodeFunctionData("approve", [
            pancakeswap.router.address,
            amountInMax,
        ]);
        const swapCallData = pancakeswap.router.interface.encodeFunctionData("swapTokensForExactTokens", [
            amountOut, // amount out
            amountInMax, // max amount in
            [tokens[2].token.address, tokens[3].token.address],
            fund.address,
            await helpers.getBlockTimestampWithDelay(100),
        ]);
        const args = [
            [0, tokens[2].token.address, approveCallData, 0],
            [1, pancakeswap.router.address, swapCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();
        const balance = await tokens[3].token.balanceOf(fund.address);

        console.log(`Swapped ${amountOut} token 2 for ${balance} token 3`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > swaps > SwapTokensForExactTokens > done --- ");
    }
    console.log(" --- bsc > interact > pancakeswap > swaps > done --- ");
};

/** LP farming on pancakeswap */
const interactLpFarming = async (fund: Contract, tokens: Token[], pancakeswap: PancakeswapProtocols) => {
    console.log(" --- bsc > interact > pancakeswap > lpFarming > start --- ");
    // addLiquidityETH - ETH and token 1
    {
        console.log(" --- bsc > interact > pancakeswap > lpFarming > addLiquidityETH > start --- ");
        const amount = ethers.utils.parseEther("0.1");
        const approveToken1CallData = tokens[1].token.interface.encodeFunctionData("approve", [
            pancakeswap.router.address,
            amount,
        ]);
        const addLiquidityCallData = pancakeswap.router.interface.encodeFunctionData("addLiquidityETH", [
            tokens[1].token.address,
            amount,
            0,
            0,
            fund.address,
            await helpers.getBlockTimestampWithDelay(100),
        ]);
        const args = [
            [0, tokens[1].token.address, approveToken1CallData, 0],
            [1, pancakeswap.router.address, addLiquidityCallData, amount],
        ];
        const txn = await (await fund.multiCall(args)).wait();
        const pair = pancakeswap.pairs[0].pair;
        const balance = await pair.balanceOf(fund.address);

        console.log(`Added liquidity and got ${balance} LP-ETH-TKN1 tokens`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > lpFarming > addLiquidity > done --- ");
    }
    // deposit
    {
        console.log(" --- bsc > interact > pancakeswap > lpFarming > farm > start --- ");
        const pair = pancakeswap.pairs[0].pair;
        const lpBalance = await pair.balanceOf(fund.address);
        const pid = pancakeswap.pidsMapper[pair.address];
        const approvePairCallData = pair.interface.encodeFunctionData("approve", [
            pancakeswap.masterChefV2.address,
            lpBalance,
        ]);
        const depositLpCallData = pancakeswap.masterChefV2.interface.encodeFunctionData("deposit", [pid, lpBalance]);
        const args = [
            [1, pair.address, approvePairCallData, 0],
            [1, pancakeswap.masterChefV2.address, depositLpCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();
        const newLpBalance = await pair.balanceOf(fund.address);
        const [lpsLocked] = await pancakeswap.masterChefV2.userInfo(pid, fund.address);

        console.log(`Deposited ${lpBalance} LPs into masterchef, left with ${newLpBalance} and ${lpsLocked} locked`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > lpFarming > farm > done --- ");
    }
    console.log(" --- bsc > interact > pancakeswap > lpFarming > done --- ");
};

/** Single pool farming on pancakeswap */
const interactSinglePoolFarming = async (fund: Contract, pancakeswap: PancakeswapProtocols) => {
    // deposit CAKE flexi
    console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > start --- ");
    {
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > depositCakePoolFlexi > start --- ");
        const amount = ethers.utils.parseEther("1");
        const approveCakeCallData = pancakeswap.cakeToken.interface.encodeFunctionData("approve", [
            pancakeswap.cakePool.address,
            amount,
        ]);
        const depositCallData = pancakeswap.cakePool.interface.encodeFunctionData("deposit", [amount, 0]);
        const unapproveCakeCallData = pancakeswap.cakeToken.interface.encodeFunctionData("approve", [
            pancakeswap.cakePool.address,
            0,
        ]);
        const args = [
            [0, pancakeswap.cakeToken.address, approveCakeCallData, 0],
            [1, pancakeswap.cakePool.address, depositCallData, 0],
            [0, pancakeswap.cakeToken.address, unapproveCakeCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();

        console.log(`Deposited ${amount} CAKE as flexi`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > depositCakePoolFlexi > done --- ");
    }
    // withdraw CAKE flexi
    {
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > withdrawCakePoolFlexi > start --- ");
        const amount = ethers.utils.parseEther("1");
        const withdrawCallData = pancakeswap.cakePool.interface.encodeFunctionData("withdrawByAmount", [amount]);
        const args = [1, pancakeswap.cakePool.address, withdrawCallData, 0];
        const txn = await (await fund.call(args)).wait();

        console.log(`Withdrawed ${amount} CAKE as flexi`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > withdrawCakePoolFlexi > done --- ");
    }
    // deposit CAKE locked (1 week)
    {
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > depositCakeLocked > start --- ");
        const amount = ethers.utils.parseEther("1");
        const approveCakeCallData = pancakeswap.cakeToken.interface.encodeFunctionData("approve", [
            pancakeswap.cakePool.address,
            amount,
        ]);
        const depositCallData = pancakeswap.cakePool.interface.encodeFunctionData("deposit", [amount, 86400 * 7]);
        const unapproveCakeCallData = pancakeswap.cakeToken.interface.encodeFunctionData("approve", [
            pancakeswap.cakePool.address,
            0,
        ]);
        const args = [
            [0, pancakeswap.cakeToken.address, approveCakeCallData, 0],
            [1, pancakeswap.cakePool.address, depositCallData, 0],
            [0, pancakeswap.cakeToken.address, unapproveCakeCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();

        console.log(`Deposited ${amount} CAKE as locked`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > depositCakePoolLocked > done --- ");
    }
    // deposit token
    {
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > depositTokenPoolLocked > start --- ");
        const poolAddress = pancakeswap.pools[0].pool.address;
        const amount = ethers.utils.parseEther("1");
        const approveCakeCallData = pancakeswap.cakeToken.interface.encodeFunctionData("approve", [
            poolAddress,
            amount,
        ]);
        const depositCallData = pancakeswap.pools[0].pool.interface.encodeFunctionData("deposit", [amount]);
        const unapproveCakeCallData = pancakeswap.cakeToken.interface.encodeFunctionData("approve", [poolAddress, 0]);
        const args = [
            [0, pancakeswap.cakeToken.address, approveCakeCallData, 0],
            [1, poolAddress, depositCallData, 0],
            [0, pancakeswap.cakeToken.address, unapproveCakeCallData, 0],
        ];
        const txn = await (await fund.multiCall(args)).wait();

        console.log(`Deposited ${amount} CAKE in token pool`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > depositTokenPoolLocked > done --- ");
    }
    // withdraw token
    {
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > withdrawTokenPoolLocked > start --- ");
        const poolAddress = pancakeswap.pools[0].pool.address;
        const amount = ethers.utils.parseEther("1");
        const withdrawCallData = pancakeswap.cakePool.interface.encodeFunctionData("withdraw", [amount]);
        const args = [1, poolAddress, withdrawCallData, 0];
        const txn = await (await fund.call(args)).wait();

        console.log(`Withdrawed ${amount} CAKE in token pool`);
        console.log(`Gas used: ${txn.gasUsed}`);
        console.log(" --- bsc > interact > pancakeswap > singlePoolFarming > withdrawTokenPoolLocked > done --- ");
    }
};

/** Interact with the pancakeswap protocols */
export default async (state: ContractsState): Promise<void> => {
    if (!state.tokens) return;
    if (!state.baseFund) return;
    if (!state.protocols?.pancakeswap) return;

    console.log(" --- bsc > interact > pancakeswap > start --- ");

    const operatorConnectedFund = state.baseFund.fund.connect(state.baseFund.roles.operators[0]);
    await interactSwaps(operatorConnectedFund, state.tokens, state.protocols.pancakeswap);
    await interactLpFarming(operatorConnectedFund, state.tokens, state.protocols.pancakeswap);
    await interactSinglePoolFarming(operatorConnectedFund, state.protocols.pancakeswap);

    console.log(" --- bsc > interact > pancakeswap > done --- ");
};
