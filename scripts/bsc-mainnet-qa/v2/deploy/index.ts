// Types
import type { Contract, ContractFactory } from "ethers";
import type { DeploymentState } from "../interfaces";

// Libraries
import { ethers } from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";

type DeployFn = (contractFactory: ContractFactory, state: DeploymentState) => Promise<Contract>;

const deployWrapper =
    (contractName: string, deployFn: DeployFn): ((state: DeploymentState) => Promise<DeploymentState>) =>
    async (state: DeploymentState): Promise<DeploymentState> => {
        try {
            console.log(`Deploying [${contractName}]`);
            const Contract = (await ethers.getContractFactory(contractName)).connect(state.deployer);
            const contract = (await deployFn(Contract, state)).connect(state.deployer);
            const txn = await (await contract.deployed()).deployTransaction.wait();
            console.log(`Deployed [${contractName}] @ ${contract.address} for ${txn.gasUsed} gas.`);

            return {
                ...state,
                contracts: { ...state.contracts, [contractName]: contract },
                deployTxns: { ...state.deployTxns, [contractName]: txn },
            };
        } catch (err) {
            console.error(`Failed to deploy [${contractName}]`);
            throw err;
        }
    };

const deployCao: DeployFn = async (factory, state) =>
    await factory.deploy(
        "Material QA",
        "MTRLQA",
        state.holders.map((holder) => holder.address),
        Array(state.holders.length).fill(ethers.utils.parseEther("100"))
    );

const deployCaoParameters: DeployFn = async (factory, state) =>
    factory.deploy(state.contracts.CAO.address, state.taskRunnerAddress);

const deployCaoHr: DeployFn = async (factory, state) => factory.deploy(state.contracts.CAO.address);

const deployMainFund: DeployFn = async (factory, _state) => factory.deploy();

const deployOpsGovernor: DeployFn = async (factory, state) =>
    factory.deploy(state.contracts.MainFund.address, state.managersAddresses, state.operatorsAddresses);

const deployFundToken: DeployFn = async (factory, state) =>
    factory.deploy(
        state.contracts.MainFund.address,
        "Transparent QA",
        "TRNSQA",
        state.holders[0].address,
        ethers.utils.parseEther("1")
    );

const deployFrontOfficeParameters: DeployFn = async (factory, state) =>
    factory.deploy(
        state.contracts.MainFund.address,
        [state.config.tokens.BUSD.address],
        [state.config.tokens.BUSD.pricing.address],
        ethers.utils.parseEther("100") // maxSingleWithdrawalFundTokenAmount
    );

const deployFrontOffice: DeployFn = async (factory, state) =>
    factory.deploy(state.contracts.MainFund.address, state.contracts.FrontOfficeParameters.address);

const deployAccounting: DeployFn = async (factory, state) =>
    factory.deploy(
        state.contracts.MainFund.address,
        ethers.utils.parseEther("1"), // initialAumValue
        ethers.utils.parseEther("1"), // initialAumValue
        ethers.utils.parseEther("0.2"), // managementFee
        100, // evaluationPeriodBlocks (300 secs = 5 mins)
        ethers.utils.parseEther("0.5"), // maxManagementFee
        20 // minEvaluationPeriodBlocks (60 secs = 1 min)
    );

const deployIncentivesManager: DeployFn = async (factory, state) => factory.deploy(state.contracts.MainFund.address);

const deployPanackaeswapLpFarmingUtil: DeployFn = async (factory, state) =>
    factory.deploy(state.config.pancakeswap.router, state.config.pancakeswap.master_chef_v2);

const deployReferralIncentive: DeployFn = async (factory, state) => factory.deploy(state.contracts.MainFund.address);

const deploymentPipeline = async (state: DeploymentState): Promise<DeploymentState> =>
    deployWrapper("CAO", deployCao)(state)
        .then(deployWrapper("CAOParameters", deployCaoParameters))
        .then(deployWrapper("HumanResources", deployCaoHr))
        .then(deployWrapper("MainFund", deployMainFund))
        .then(deployWrapper("OpsGovernor", deployOpsGovernor))
        .then(deployWrapper("MainFundToken", deployFundToken))
        .then(deployWrapper("FrontOfficeParameters", deployFrontOfficeParameters))
        .then(deployWrapper("FrontOffice", deployFrontOffice))
        .then(deployWrapper("Accounting", deployAccounting))
        .then(deployWrapper("IncentivesManager", deployIncentivesManager))
        .then(deployWrapper("PancakeswapLpFarmingUtil", deployPanackaeswapLpFarmingUtil))
        .then(deployWrapper("ReferralIncentive", deployReferralIncentive));

export default async (state: DeploymentState): Promise<DeploymentState> => {
    console.log("---------------------------------------------------------");
    console.log("---------------------- Deployments ----------------------");

    const deployedState = await deploymentPipeline(state);

    const deploymentGasUsed = Object.values(deployedState.deployTxns).reduce(
        (current, txn) => current.add(txn.gasUsed),
        BigNumber.from(0)
    );

    console.log(`Total Deployment Gas Used: ${deploymentGasUsed}`);
    console.log("---------------------------------------------------------");
    console.log();

    return deployedState;
};
