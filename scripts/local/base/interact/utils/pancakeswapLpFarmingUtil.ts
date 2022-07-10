/**
 * Interactions with the Pancakeswap LP Farming util for the Base Fund.
 *
 * Integration tests the transactions with the Pancakeswap LP Farming util
 * where the absence of reverts/errors indicates that it works.
 */

// Types
import type { Contract } from "ethers";
import type { ContractsState, Token, PancakeswapProtocols } from "../../interfaces";

// Library
import { ethers } from "hardhat";

/** LP farming via utils on pancakeswap */
const interactLpFarmingUtils = async (
    fund: Contract,
    tokens: Token[],
    pancakeswap: PancakeswapProtocols,
    utils: Contract
) => {
    console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > start --- ");
    // farmTokenAndETH - token 0 and token 1
    {
        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > farmTokenAndETH > start --- ");
        const pair = pancakeswap.pairs[0].pair;
        const amount = ethers.utils.parseEther("2");
        const pid = pancakeswap.pidsMapper[pair.address];
        const farmTokenAndETHCallParams = [
            tokens[1].token.address,
            amount,
            amount,
            0, // no minimum output
            0, // no minimum output
            pid,
            true, // farmAllBalance
        ];
        const farmTokenAndETHCallData = utils.interface.encodeFunctionData("farmTokenAndETH", [
            farmTokenAndETHCallParams,
        ]);
        const args = [2, utils.address, farmTokenAndETHCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const newLpBalance = await pair.balanceOf(fund.address);
        const [lpsLocked] = await pancakeswap.masterChefV2.userInfo(pid, fund.address);

        console.log(`Added ${amount} token 2 and 3 of liquidity, left with ${newLpBalance} and ${lpsLocked} locked`);
        console.log(`Gas used: ${txn.gasUsed}`);

        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > farmTokenAndETH > done --- ");
    }
    // unfarmTokenAndETH - token 0 and 1
    {
        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > unfarmTokenAndETH > start --- ");
        const pair = pancakeswap.pairs[0].pair;
        const amount = ethers.utils.parseEther("1");
        const pid = pancakeswap.pidsMapper[pair.address];
        const unfarmTokensCallParams = [
            tokens[1].token.address,
            amount,
            0, // no minimum output
            0, // no minimum output
            pid,
        ];
        const unfarmTokenAndETHCallData = utils.interface.encodeFunctionData("unfarmTokenAndETH", [
            unfarmTokensCallParams,
        ]);
        const args = [2, utils.address, unfarmTokenAndETHCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const [lpsLocked] = await pancakeswap.masterChefV2.userInfo(pid, fund.address);

        console.log(`Removed ${amount} of LPs, left with ${lpsLocked} locked`);
        console.log(`Gas used: ${txn.gasUsed}`);

        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > unfarmTokenAndETH > done --- ");
    }
    // farmTokens - token 2 and token 3
    {
        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > farmTokens > start --- ");
        const pair = pancakeswap.pairs[5].pair;
        const amount = ethers.utils.parseEther("2");
        const pid = pancakeswap.pidsMapper[pair.address];
        const farmTokensCallParams = [
            tokens[2].token.address,
            tokens[3].token.address,
            amount,
            amount,
            0, // no minimum output
            0, // no minimum output
            pid,
            false, // farmAllBalance
        ];
        const farmTokensCallData = utils.interface.encodeFunctionData("farmTokens", [farmTokensCallParams]);
        const args = [2, utils.address, farmTokensCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const newLpBalance = await pair.balanceOf(fund.address);
        const [lpsLocked] = await pancakeswap.masterChefV2.userInfo(pid, fund.address);

        console.log(`Added ${amount} token 2 and 3 of liquidity, left with ${newLpBalance} and ${lpsLocked} locked`);
        console.log(`Gas used: ${txn.gasUsed}`);

        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > farmTokens > done --- ");
    }
    // unfarmTokens - token 2 and token 3
    {
        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > unfarmTokens > start --- ");
        const pair = pancakeswap.pairs[5].pair;
        const amount = ethers.utils.parseEther("1");
        const pid = pancakeswap.pidsMapper[pair.address];
        const unfarmTokensCallParams = [
            tokens[2].token.address,
            tokens[3].token.address,
            amount,
            0, // no minimum output
            0, // no minimum output
            pid,
        ];
        const unfarmTokensCallData = utils.interface.encodeFunctionData("unfarmTokens", [unfarmTokensCallParams]);
        const args = [2, utils.address, unfarmTokensCallData, 0];
        const txn = await (await fund.call(args)).wait();
        const [lpsLocked] = await pancakeswap.masterChefV2.userInfo(pid, fund.address);

        console.log(`Removed ${amount} of LPs, left with ${lpsLocked} locked`);
        console.log(`Gas used: ${txn.gasUsed}`);

        console.log(" --- bsc > interact > pancakeswap > utils > lpFarmingUtils > unfarmTokens > done --- ");
    }
    console.log(" --- bsc > interact > pancakeswap > utils > lpFarm > done --- ");
};

/** Interact with the pancakeswap protocols */
export default async (state: ContractsState): Promise<void> => {
    if (!state.tokens) return;
    if (!state.baseFund) return;
    if (!state.protocols?.pancakeswap) return;

    console.log(" --- bsc > interact > utils > pancakeswapLpFarmingUtil > start --- ");

    const operatorConnectedFund = state.baseFund.fund.connect(state.baseFund.roles.operators[0]);
    await interactLpFarmingUtils(
        operatorConnectedFund,
        state.tokens,
        state.protocols.pancakeswap,
        state.baseFund.utils.pancakeswapLpFarmingUtil
    );

    console.log(" --- bsc > interact > utils > pancakeswapLpFarmingUtil > done --- ");
};
