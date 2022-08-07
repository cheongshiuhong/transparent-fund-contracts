// Types
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Contract } from "ethers";
import type { ContractsState } from "../interfaces";

// Libraries
import { ethers } from "hardhat";

/** Executes through creating proposal and voting then executing */
const executeThroughCAOGovernanceProcess = async (
    cao: Contract,
    holders: SignerWithAddress[],
    callAddresses: string[],
    callDatas: string[],
    callValues: number[]
): Promise<void> => {
    const receipt = await (
        await cao.connect(holders[0]).createProposal("Proposal", 0, 1200, callAddresses, callDatas, callValues)
    ).wait();
    const proposalId = receipt.events[0].args[0].toNumber();

    // All to vote in approval
    await Promise.all(
        holders.map(async (holder) => await (await cao.connect(holder).vote(proposalId, 0, "vote")).wait())
    );

    // Execute the proposal
    await (await cao.connect(holders[0]).executeProposal(proposalId, { gasLimit: 5_000_000 })).wait();
};

/** Setup the base fund and its supporting contracts */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.tokens) return state;

    console.log("--- bsc > deploy > mainFund > start ---");

    // Assign roles to the signers
    const [holder1, holder2, holder3, manager1, manager2, operator1, operator2] = state.signers;
    const holders = [holder1, holder2, holder3];
    const managers = [manager1, manager2];
    const operators = [operator1, operator2];

    /****************/
    /** Deployments */
    /****************/

    // Deploy the CAO
    const taskRunner = state.signers[3];
    const CAO = await ethers.getContractFactory("CAO");
    const cao = await CAO.deploy(
        "Material",
        "MTRL",
        holders.map((holder) => holder.address),
        Array(holders.length).fill(ethers.utils.parseEther("10000"))
    );
    const caoDeployTxn = await (await cao.deployed()).deployTransaction.wait();

    // Get the CAO token and delegate voting power
    const CAOToken = await ethers.getContractFactory("CAOToken");
    const caoToken = CAOToken.attach(await cao.getCAOTokenAddress());
    await Promise.all(holders.map(async (holder) => caoToken.connect(holder).delegate(holder.address)));

    // Deploy the CAO Parameters
    const CAOParameters = await ethers.getContractFactory("CAOParameters");
    const caoParameters = await CAOParameters.deploy(cao.address, taskRunner.address);
    const caoParametersDeployTxn = await (await caoParameters.deployed()).deployTransaction.wait();
    await (await cao.setCAOParameters(caoParameters.address)).wait();

    // Deploy the CAO Human Resources
    const HumanResources = await ethers.getContractFactory("HumanResources");
    const humanResources = await HumanResources.deploy(cao.address);
    const humanResourcesDeployTxn = await (await humanResources.deployed()).deployTransaction.wait();
    await (await cao.setCAOHelpers(humanResources.address)).wait();

    // Deploy the main fund
    const Fund = await ethers.getContractFactory("MainFund");
    const fund = await Fund.deploy();
    const fundDeployTxn = await (await fund.deployed()).deployTransaction.wait();

    // Deploy the base fund helpers
    const OpsGovernor = await ethers.getContractFactory("OpsGovernor");
    const opsGovernor = await OpsGovernor.deploy(
        fund.address,
        managers.map((manager) => manager.address),
        operators.map((operator) => operator.address)
    );
    const opsGovernorDeployTxn = await (await opsGovernor.deployed()).deployTransaction.wait();
    await (await fund.setBaseFundHelpers(opsGovernor.address)).wait();

    // Deploy the main fund helpers
    const FundToken = await ethers.getContractFactory("MainFundToken");
    const FrontOfficeParameters = await ethers.getContractFactory("FrontOfficeParameters");
    const FrontOffice = await ethers.getContractFactory("FrontOffice");
    const Accounting = await ethers.getContractFactory("Accounting");
    const IncentivesManager = await ethers.getContractFactory("IncentivesManager");

    const fundToken = await FundToken.deploy(
        fund.address,
        "Transparent",
        "TRNS",
        holders[0].address,
        ethers.utils.parseEther("1")
    );
    const frontOfficeParameters = await FrontOfficeParameters.deploy(
        fund.address,
        state.tokens.map((token) => token.token.address),
        state.tokens.map((token) => token.chainlinkOracle.address),
        ethers.utils.parseEther("100") // maxSingleWithdrawalFundTokenAmount
    );
    const frontOffice = await FrontOffice.deploy(fund.address, frontOfficeParameters.address);
    const accounting = await Accounting.deploy(
        fund.address,
        ethers.utils.parseEther("1"), // initialAumValue
        ethers.utils.parseEther("1"), // initialFundTokenSupply
        ethers.utils.parseEther("0.2"), // managementFee
        2, // evaluationPeriodBlocks
        ethers.utils.parseEther("0.5"), // maxManagementFee
        2 // minEvaluationPeriodBlocks
    );
    const incentivesManager = await IncentivesManager.deploy(fund.address);

    const fundTokenDeployTxn = await (await fundToken.deployed()).deployTransaction.wait();
    const frontOfficeParametersDeployTxn = await (await frontOfficeParameters.deployed()).deployTransaction.wait();
    const frontOfficeDeployTxn = await (await frontOffice.deployed()).deployTransaction.wait();
    const accountingDeployTxn = await (await accounting.deployed()).deployTransaction.wait();
    const incentivesManagerDeployTxn = await (await incentivesManager.deployed()).deployTransaction.wait();

    await (
        await fund.setMainFundHelpers(
            cao.address,
            fundToken.address,
            accounting.address,
            frontOffice.address,
            incentivesManager.address
        )
    ).wait();

    // Deploy the incentives
    const ReferralIncentive = await ethers.getContractFactory("ReferralIncentive");
    const referralIncentive = await ReferralIncentive.deploy(fund.address);
    const referralIncentiveDeployTxn = await (await referralIncentive.deployed()).deployTransaction.wait();

    // Log the deployment gas details
    console.log(`CAO Deployment Gas Used: ${caoDeployTxn.gasUsed}`);
    console.log(`CAOParameters Deployment Gas Used: ${caoParametersDeployTxn.gasUsed}`);
    console.log(`HumanResources Deployment Gas Used: ${humanResourcesDeployTxn.gasUsed}`);
    console.log(`Fund Deployment Gas Used: ${fundDeployTxn.gasUsed}`);
    console.log(`OpsGovernor Deployment Gas Used: ${opsGovernorDeployTxn.gasUsed}`);
    console.log(`FundToken Deployment Gas Used: ${fundTokenDeployTxn.gasUsed}`);
    console.log(`FrontOfficeParameters Deployment Gas Used: ${frontOfficeParametersDeployTxn.gasUsed}`);
    console.log(`FrontOffice Deployment Gas Used: ${frontOfficeDeployTxn.gasUsed}`);
    console.log(`Accounting Deployment Gas Used: ${accountingDeployTxn.gasUsed}`);
    console.log(`IncentivesManager Deployment Gas Used: ${incentivesManagerDeployTxn.gasUsed}`);
    console.log(`ReferralIncentive Deployment Gas Used: ${referralIncentiveDeployTxn.gasUsed}`);
    console.log(
        `Total Gas Used: ${caoDeployTxn.gasUsed
            .add(caoParametersDeployTxn.gasUsed)
            .add(humanResourcesDeployTxn.gasUsed)
            .add(fundDeployTxn.gasUsed)
            .add(opsGovernorDeployTxn.gasUsed)
            .add(fundTokenDeployTxn.gasUsed)
            .add(frontOfficeParametersDeployTxn.gasUsed)
            .add(frontOfficeDeployTxn.gasUsed)
            .add(accountingDeployTxn.gasUsed)
            .add(incentivesManagerDeployTxn.gasUsed)
            .add(referralIncentiveDeployTxn.gasUsed)}`
    );

    /******************/
    /** Initial Setup */
    /******************/

    // Send in the tokens into the fund for the initial deposit
    await (await state.tokens[0].token.connect(holders[0]).transfer(fund.address, ethers.utils.parseEther("1"))).wait();

    // Initial CAO state updates
    await executeThroughCAOGovernanceProcess(
        cao,
        holders,
        [
            ...Array(holders.length).fill(humanResources.address),
            caoParameters.address,
            caoParameters.address,
            incentivesManager.address,
        ],
        [
            // Employees
            ...holders.map((holder) =>
                humanResources.interface.encodeFunctionData("addEmployee", [
                    holder.address,
                    ethers.utils.parseEther("0.001"),
                ])
            ),
            // CAO Parameters
            caoParameters.interface.encodeFunctionData("setReserveTokensOracles", [
                state.tokens.map((token) => token.token.address),
                state.tokens.map((token) => token.chainlinkOracle.address),
            ]),
            caoParameters.interface.encodeFunctionData("addFundTokens", [[fundToken.address]]),
            // Incentives
            incentivesManager.interface.encodeFunctionData("addIncentive", [referralIncentive.address]),
        ],
        [...Array(holders.length).fill(0), 0, 0, 0]
    );

    console.log("--- bsc > deploy > mainFund > done ---");

    return {
        ...state,
        mainFund: {
            fund,
            roles: { holders, managers, operators, taskRunner },
            opsGovernor,
            fundToken,
            cao,
            caoToken,
            caoParameters,
            humanResources,
            accounting,
            frontOffice,
            incentivesManager,
            incentives: { referral: referralIncentive },
        },
    };
};
