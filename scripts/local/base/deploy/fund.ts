// Types
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Contract } from "ethers";
import type { ContractsState } from "../interfaces";

// Libraries
import { ethers } from "hardhat";

// Code
import helpers from "../helpers";

/** Executes through creating proposal and voting then executing */
const executeThroughGovernanceProcess = async (
    opsGovernor: Contract,
    managers: SignerWithAddress[],
    callData: string
): Promise<void> => {
    const receipt = await (await opsGovernor.connect(managers[0]).createProposal("A proposal", 100, callData)).wait();
    const proposalId = receipt.events[0].args[0].toNumber();

    // All to vote in approval
    await Promise.all(
        managers.slice(1).map(async (manager) => await (await opsGovernor.connect(manager).vote(proposalId, 0)).wait())
    );

    // Execute the proposal
    await (await opsGovernor.connect(managers[0]).executeProposal(proposalId)).wait();
};

/** Setup the base fund and its supporting contracts */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.tokens) return state;
    if (!state.protocols) return state;
    if (!state.protocols.pancakeswap) return state;
    if (!state.protocols.venus) return state;

    console.log("--- bsc > deploy > baseFund > start ---");

    // Assign roles to the signers
    const [manager1, manager2, operator1, operator2] = state.signers;
    const managers = [manager1, manager2];
    const operators = [operator1, operator2];

    // Deploy the fund entity
    const Fund = await ethers.getContractFactory("BaseFund");
    const fund = await Fund.deploy();
    await fund.deployed();

    // Deploy the helper contracts
    const OpsGovernor = await ethers.getContractFactory("OpsGovernor");

    const opsGovernor = await OpsGovernor.deploy(
        fund.address,
        managers.map((manager) => manager.address),
        operators.map((operator) => operator.address)
    );

    await opsGovernor.deployed();

    // Set the reference to the ops governor contract
    await (await fund.setOpsGovernor(opsGovernor.address)).wait();

    // Register the tokens
    const tokens = [...state.tokens.map((each) => each.token.address), state.protocols.pancakeswap.cakeToken.address];
    await executeThroughGovernanceProcess(
        opsGovernor,
        managers,
        opsGovernor.interface.encodeFunctionData("registerTokens", [tokens])
    );

    // Register the protocols
    const protocols = [
        // Pancakeswap
        state.protocols.pancakeswap.masterChefV2.address,
        state.protocols.pancakeswap.router.address,
        state.protocols.pancakeswap.cakePool.address,
        ...state.protocols.pancakeswap.pools.map((details) => details.pool.address),
        ...state.protocols.pancakeswap.pairs.map((details) => details.pair.address),
        // Venus
        state.protocols.venus.comptrollerG5.address,
        ...state.protocols.venus.lendingPools.map((details) => details.pool.address),
    ];
    await executeThroughGovernanceProcess(
        opsGovernor,
        managers,
        opsGovernor.interface.encodeFunctionData("registerProtocols", [protocols])
    );

    // Deploy and register the utils
    const PancakeswapLpFarmingUtil = await ethers.getContractFactory("PancakeswapLpFarmingUtil");
    const pancakeswapLpFarmingUtil = await PancakeswapLpFarmingUtil.deploy(
        state.protocols.pancakeswap.router.address,
        state.protocols.pancakeswap.masterChefV2.address
    );
    await pancakeswapLpFarmingUtil.deployed();

    const utils = [pancakeswapLpFarmingUtil.address];
    await executeThroughGovernanceProcess(
        opsGovernor,
        managers,
        opsGovernor.interface.encodeFunctionData("registerUtils", [utils])
    );

    // Send some ETH to the fund
    await helpers.sendEth(state.signers[0], fund.address, ethers.utils.parseEther("100"));

    // Mint tokens into the fund directly
    await Promise.all(
        state.tokens.map(async (each) => each.token.mint(fund.address, ethers.utils.parseEther("10000")))
    );
    await state.protocols.pancakeswap.cakeToken.mint(fund.address, ethers.utils.parseEther("10000"));

    console.log("--- bsc > deploy > baseFund > done ---");

    return {
        ...state,
        baseFund: {
            fund,
            opsGovernor,
            roles: {
                managers,
                operators,
            },
            utils: { pancakeswapLpFarmingUtil },
        },
    };
};
