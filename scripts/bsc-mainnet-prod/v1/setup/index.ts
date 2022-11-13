// Types
import { DeploymentState } from "../interfaces";

// Libraries
import { ethers } from "hardhat";

// Code
import params from "../params";
// import executeCaoGovernance from "./executeCaoGovernance";
import executeOpsGovernance from "./executeOpsGovernance";

const setDependencies = async (state: DeploymentState): Promise<void> => {
    console.log("Setting dependencies.");
    await (await state.contracts.CAO.setCAOParameters(state.contracts.CAOParameters.address)).wait();
    await (await state.contracts.CAO.setCAOHelpers(state.contracts.HumanResources.address)).wait();
    await (await state.contracts.MainFund.setBaseFundHelpers(state.contracts.OpsGovernor.address)).wait();
    await (
        await state.contracts.MainFund.setMainFundHelpers(
            state.contracts.CAO.address,
            state.contracts.MainFundToken.address,
            state.contracts.Accounting.address,
            state.contracts.FrontOffice.address,
            state.contracts.IncentivesManager.address
        )
    ).wait();
    console.log("Done setting dependencies.");
};

const setupBaseFund = async (state: DeploymentState): Promise<void> => {
    console.log("Setting up base fund.");
    const tokensToRegister = Object.values(state.config.tokens).map((token) => token.address);
    await executeOpsGovernance(
        state.contracts.OpsGovernor,
        state.contracts.OpsGovernor.interface.encodeFunctionData("registerTokens", [tokensToRegister])
    );
    const protocolsToRegister = [
        // Pancakeswap
        state.config.pancakeswap.cake_pool,
        ...Object.values(state.config.pancakeswap.smart_chefs),
        state.config.pancakeswap.master_chef_v2,
        state.config.pancakeswap.router,
        ...Object.values(state.config.pancakeswap.pairs).map((each) => each.address),
        // Venus
        state.config.venus.unitroller,
        ...Object.values(state.config.venus.pools),
    ];
    await executeOpsGovernance(
        state.contracts.OpsGovernor,
        state.contracts.OpsGovernor.interface.encodeFunctionData("registerProtocols", [protocolsToRegister])
    );
    const utilsToRegister = [state.contracts.PancakeswapLpFarmingUtil.address];
    await executeOpsGovernance(
        state.contracts.OpsGovernor,
        state.contracts.OpsGovernor.interface.encodeFunctionData("registerUtils", [utilsToRegister])
    );
    console.log("Done setting up base fund.");
};

// const setupMainFund = async (state: DeploymentState): Promise<void> => {
//     console.log("Setting up main fund.");

//     // Get the CAO token and delegate voting power
//     console.log("Initial Setup (Main Fund) - Delegating Voting Power");
//     const CAOToken = await ethers.getContractFactory("CAOToken");
//     const caoToken = CAOToken.attach(await state.contracts.CAO.getCAOTokenAddress());
//     await Promise.all(state.holders.map(async (holder) => caoToken.connect(holder).delegate(holder.address)));
//     console.log("Initial Setup (Main Fund) - Delegated Voting Power");

//     // CAO Governance
//     const incentivesToRegister = [state.contracts.ReferralIncentive.address];
//     await executeCaoGovernance(
//         state.contracts.CAO,
//         state.holders,
//         [
//             // Employees
//             ...Array(state.holders.length).fill(state.contracts.HumanResources.address),
//             // CAO Parameters
//             state.contracts.CAOParameters.address,
//             state.contracts.CAOParameters.address,
//             // Incentives
//             ...Array(incentivesToRegister.length).fill(state.contracts.IncentivesManager.address),
//         ],
//         [
//             // Employees
//             ...state.holders.map((holder) =>
//                 state.contracts.HumanResources.interface.encodeFunctionData("addEmployee", [
//                     holder.address,
//                     ethers.utils.parseEther("0.00001"), // remuneration per block
//                 ])
//             ),
//             // CAO Parameters
//             state.contracts.CAOParameters.interface.encodeFunctionData("setReserveTokensOracles", [
//                 [state.config.tokens.BUSD.address],
//                 [state.config.tokens.BUSD.pricing.address],
//             ]),
//             state.contracts.CAOParameters.interface.encodeFunctionData("addFundTokens", [
//                 [state.contracts.MainFundToken.address],
//             ]),
//             // Incentives
//             ...Object.values(incentivesToRegister).map((incentive) =>
//                 state.contracts.IncentivesManager.interface.encodeFunctionData("addIncentive", [incentive])
//             ),
//         ],
//         [...Array(state.holders.length).fill(0), 0, 0, ...Array(incentivesToRegister.length).fill(0)]
//     );
//     console.log("Done setting up main fund.");
// };

export default async (state: DeploymentState): Promise<DeploymentState> => {
    console.log("--------------------------------------------------------");
    console.log("--------------- Initialization and Setup ---------------");
    await setDependencies(state);

    // Initial deposit
    console.log("Depositing initial amount.");
    const ERC20 = await ethers.getContractFactory("ERC20");
    const initialDepositTxn = await (
        await ERC20.attach(state.config.tokens.BUSD.address)
            .connect(state.deployer)
            .transfer(state.contracts.MainFund.address, params.INITIAL_AUM_VALUE)
    ).wait();
    console.log(`Deposited initial amount. Gas used: ${initialDepositTxn.gasUsed}`);

    await setupBaseFund(state);
    // await setupMainFund(state);

    console.log("--------------------------------------------------------");

    return state;
};
