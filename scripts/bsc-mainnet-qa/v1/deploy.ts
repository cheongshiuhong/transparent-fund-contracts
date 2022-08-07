// Types
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Contract } from "ethers";

// Libraries
import fs from "fs";
import yaml from "js-yaml";
import { ethers } from "hardhat";

/* eslint-disable camelcase */

type TokenConfig = {
    address: string;
    decimals: number;
    pricing: { address: string };
};
type TokensConfig = Record<string, TokenConfig>;
type PancakeswapConfig = {
    cake_pool: string;
    smart_chefs: Record<string, string>;
    master_chef_v2: string;
    router: string;
    pairs: Record<string, { address: string }>;
};
type VenusConfig = {
    unitroller: string;
    lens: string;
    pools: Record<string, string>;
};
type Config = {
    tokens: TokensConfig;
    pancakeswap: PancakeswapConfig;
    venus: VenusConfig;
};

const loadConfig = (): Config => {
    const path = "configs/bsc-mainnet/";

    // Read the config
    const tokens = yaml.load(fs.readFileSync(path + "tokens.yaml").toString()) as TokensConfig;
    const pancakeswap = yaml.load(fs.readFileSync(path + "protocols/pancakeswap.yaml").toString()) as PancakeswapConfig;
    const venus = yaml.load(fs.readFileSync(path + "protocols/venus.yaml").toString()) as VenusConfig;

    return { tokens, pancakeswap, venus };
};

/** Executes through creating proposal and voting then executing */
const executeThroughOpsGovernanceProcess = async (
    opsGovernor: Contract,
    managers: SignerWithAddress[],
    callData: string
): Promise<void> => {
    const receipt = await (await opsGovernor.connect(managers[0]).createProposal("A proposal", 1_000, callData)).wait();
    const proposalId = receipt.events[0].args[0].toNumber();

    // All to vote in approval
    await Promise.all(
        managers.slice(1).map(async (manager) => await (await opsGovernor.connect(manager).vote(proposalId, 0)).wait())
    );

    // Execute the proposal
    await (await opsGovernor.connect(managers[0]).executeProposal(proposalId)).wait();
};

/** Executes through creating proposal and voting then executing */
const executeThroughCAOGovernanceProcess = async (
    cao: Contract,
    holders: SignerWithAddress[],
    callAddresses: string[],
    callDatas: string[],
    callValues: number[]
): Promise<void> => {
    const receipt = await (
        await cao.connect(holders[0]).createProposal("Proposal", 0, 1_200, callAddresses, callDatas, callValues)
    ).wait();
    const proposalId = receipt.events[0].args[0].toNumber();

    // All to vote in approval
    await Promise.all(
        holders.map(async (holder) => await (await cao.connect(holder).vote(proposalId, 0, "vote")).wait())
    );

    // Execute the proposal
    await (await cao.connect(holders[0]).executeProposal(proposalId, { gasLimit: 5_000_000 })).wait();
};

const USER_ADDRESS = "";

export default async (): Promise<void> => {
    // Assign the roles
    const [deployer, tester] = await ethers.getSigners();

    const holders = [deployer, tester];
    const managers = [deployer, tester];
    const managersAddresses = [...managers.map((manager) => manager.address)];
    const operators = [deployer, tester];
    const operatorsAddresses = [...operators.map((operator) => operator.address), USER_ADDRESS];
    const taskRunner = tester;

    const config = loadConfig();

    // Deploy the CAO
    console.log("Deploying the CAO");
    const CAO = await ethers.getContractFactory("CAO");
    const cao = await CAO.connect(deployer).deploy(
        "Material QA",
        "MTRLQA",
        holders.map((holder) => holder.address),
        Array(holders.length).fill(ethers.utils.parseEther("100"))
    );
    const caoDeployTxn = await (await cao.deployed()).deployTransaction.wait();
    console.log("Deployed the CAO", cao.address);

    // Deploy the CAO Parameters
    console.log("Deploying the CAO Parameters");
    const CAOParameters = await ethers.getContractFactory("CAOParameters");
    const caoParameters = await CAOParameters.connect(deployer).deploy(cao.address, taskRunner.address);
    const caoParametersDeployTxn = await (await caoParameters.deployed()).deployTransaction.wait();
    await (await cao.connect(deployer).setCAOParameters(caoParameters.address)).wait();
    console.log("Deployed the CAO Parameters", caoParameters.address);

    // Deploy the CAO Human Resources
    console.log("Deploying the CAO Human Resources");
    const HumanResources = await ethers.getContractFactory("HumanResources");
    const humanResources = await HumanResources.connect(deployer).deploy(cao.address);
    const humanResourcesDeployTxn = await (await humanResources.deployed()).deployTransaction.wait();
    await (await cao.connect(deployer).setCAOHelpers(humanResources.address)).wait();
    console.log("Deployed the CAO Human Resources", humanResources.address);

    // Deploy the main fund
    console.log("Deploying the Main Fund");
    const Fund = await ethers.getContractFactory("MainFund");
    const fund = await Fund.connect(deployer).deploy();
    const fundDeployTxn = await (await fund.deployed()).deployTransaction.wait();
    console.log("Deployed the Main Fund", fund.address);

    // Deploy the base fund helpers
    console.log("Deploying the Base Fund Helpers");
    const OpsGovernor = await ethers.getContractFactory("OpsGovernor");
    const opsGovernor = await OpsGovernor.connect(deployer).deploy(fund.address, managersAddresses, operatorsAddresses);
    const opsGovernorDeployTxn = await (await opsGovernor.deployed()).deployTransaction.wait();
    await (await fund.connect(deployer).setBaseFundHelpers(opsGovernor.address)).wait();
    console.log("Deployed the Base Fund Helpers", { opsGovernor: opsGovernor.address });

    // Deploy the utils
    console.log("Deploying the Utils");
    const PancakeswapLpFarmingUtil = await ethers.getContractFactory("PancakeswapLpFarmingUtil");
    const pancakeswapLpFarmingUtil = await PancakeswapLpFarmingUtil.connect(deployer).deploy(
        config.pancakeswap.router,
        config.pancakeswap.master_chef_v2
    );
    const pancakeswapLpFarmingUtilDeployTxn = await (
        await pancakeswapLpFarmingUtil.deployed()
    ).deployTransaction.wait();
    const utils = { pancakeswapLpFarmingUtil };
    console.log(
        "Deployed the Utils",
        Object.entries(utils).reduce((current, [name, each]) => ({ ...current, [name]: each.address }), {})
    );

    // Deploy the main fund helpers
    console.log("Deploying the Fund Token");
    const FundToken = await ethers.getContractFactory("MainFundToken");
    const fundToken = await FundToken.connect(deployer).deploy(
        fund.address,
        "Transparent QA",
        "TRNSQA",
        holders[0].address,
        ethers.utils.parseEther("1")
    );
    const fundTokenDeployTxn = await (await fundToken.deployed()).deployTransaction.wait();
    console.log("Deployed the Fund Token", fundToken.address);

    console.log("Deploying the Front Office Parameters");
    const FrontOfficeParameters = await ethers.getContractFactory("FrontOfficeParameters");
    const frontOfficeParameters = await FrontOfficeParameters.connect(deployer).deploy(
        fund.address,
        [config.tokens.BUSD.address],
        [config.tokens.BUSD.pricing.address],
        ethers.utils.parseEther("100") // maxSingleWithdrawalFundTokenAmount
    );
    const frontOfficeParametersDeployTxn = await (await frontOfficeParameters.deployed()).deployTransaction.wait();
    console.log("Deployed the Front Office Parameters", frontOfficeParameters.address);

    console.log("Deploying the Front Office");
    const FrontOffice = await ethers.getContractFactory("FrontOffice");
    const frontOffice = await FrontOffice.connect(deployer).deploy(fund.address, frontOfficeParameters.address);
    const frontOfficeDeployTxn = await (await frontOffice.deployed()).deployTransaction.wait();
    console.log("Deployed the Front Office", frontOffice.address);

    console.log("Deploying the Accounting");
    const Accounting = await ethers.getContractFactory("Accounting");
    const accounting = await Accounting.connect(deployer).deploy(
        fund.address,
        ethers.utils.parseEther("1"), // initialAumValue
        ethers.utils.parseEther("1"), // initialFundTokenSupply
        ethers.utils.parseEther("0.2"), // managementFee
        100, // evaluationPeriodBlocks (300 secs = 5 min)
        ethers.utils.parseEther("0.5"), // maxManagementFee
        20 // minEvaluationPeriodBlocks (60 secs = 1 min)
    );
    const accountingDeployTxn = await (await accounting.deployed()).deployTransaction.wait();
    console.log("Deployed the Accounting", accounting.address);

    console.log("Deploying the Incentives Manager");
    const IncentivesManager = await ethers.getContractFactory("IncentivesManager");
    const incentivesManager = await IncentivesManager.connect(deployer).deploy(fund.address);
    const incentivesManagerDeployTxn = await (await incentivesManager.deployed()).deployTransaction.wait();
    console.log("Deployed the Incentives Manager", incentivesManager.address);

    await (
        await fund
            .connect(deployer)
            .setMainFundHelpers(
                cao.address,
                fundToken.address,
                accounting.address,
                frontOffice.address,
                incentivesManager.address
            )
    ).wait();
    console.log("Deployed the Main Fund Helpers", {
        fundToken: fundToken.address,
        frontOfficeParameters: frontOfficeParameters.address,
        frontOffice: frontOffice.address,
        accounting: accounting.address,
        incentivesManager: incentivesManager.address,
    });

    // Deploy the incentives
    console.log("Deploying the Incentives");
    const ReferralIncentive = await ethers.getContractFactory("ReferralIncentive");
    const referralIncentive = await ReferralIncentive.connect(deployer).deploy(fund.address);
    const referralIncentiveDeployTxn = await (await referralIncentive.deployed()).deployTransaction.wait();
    const incentives = { referralIncentive };
    console.log(
        "Deployed the Incentives",
        Object.entries(incentives).reduce((current, [name, each]) => ({ ...current, [name]: each.address }), {})
    );

    /******************************/
    /** Initial Setup - Base Fund */
    /******************************/
    // Register the tokens
    console.log("Initial Setup (Base Fund) - Registering Tokens");
    const tokensToRegister = Object.entries(config.tokens).map(([_, each]) => each.address);
    await executeThroughOpsGovernanceProcess(
        opsGovernor,
        managers,
        opsGovernor.interface.encodeFunctionData("registerTokens", [tokensToRegister])
    );
    console.log("Initial Setup (Base Fund) - Registered Tokens");

    // Register the protocols
    console.log("Initial Setup (Base Fund) - Registering Protocols");
    const protocolsToRegister = [
        // Pancakeswap
        config.pancakeswap.cake_pool,
        ...Object.entries(config.pancakeswap.smart_chefs).map(([_, address]) => address),
        config.pancakeswap.master_chef_v2,
        config.pancakeswap.router,
        ...Object.entries(config.pancakeswap.pairs).map(([_, each]) => each.address),
        // Venus
        config.venus.unitroller,
        ...Object.entries(config.venus.pools).map(([_, address]) => address),
    ];
    await executeThroughOpsGovernanceProcess(
        opsGovernor,
        managers,
        opsGovernor.interface.encodeFunctionData("registerProtocols", [protocolsToRegister])
    );
    console.log("Initial Setup (Base Fund) - Registered Protocols");

    // Register the utils
    console.log("Initial Setup (Base Fund) - Registering Utils");
    const utilsToRegister = Object.entries(utils).map(([_, each]) => each.address);
    await executeThroughOpsGovernanceProcess(
        opsGovernor,
        managers,
        opsGovernor.interface.encodeFunctionData("registerUtils", [utilsToRegister])
    );
    console.log("Initial Setup (Base Fund) - Registered Utils");

    /******************************/
    /** Initial Setup - Main Fund */
    /******************************/
    console.log("Initial Setup (Main Fund) - Depositing Initial");
    // Send in the tokens into the fund for the initial deposit
    const ERC20 = await ethers.getContractFactory("ERC20");
    const initialDepositTxn = await (
        await ERC20.attach(config.tokens.BUSD.address)
            .connect(deployer)
            .transfer(fund.address, ethers.utils.parseEther("1"))
    ).wait();
    console.log("Initial Setup (Main Fund) - Deposited Initial");

    // Get the CAO token and delegate voting power
    console.log("Initial Setup (Main Fund) - Delegating Voting Power");
    const CAOToken = await ethers.getContractFactory("CAOToken");
    const caoToken = CAOToken.attach(await cao.getCAOTokenAddress());
    await Promise.all(holders.map(async (holder) => caoToken.connect(holder).delegate(holder.address)));
    console.log("Initial Setup (Main Fund) - Delegated Voting Power");

    // Initial CAO state updates
    console.log("Initial Setup (Main Fund) - Updating Initial CAO States");
    const incentivesToRegister = Object.entries(incentives).map(([_, each]) => each.address);
    await executeThroughCAOGovernanceProcess(
        cao,
        holders,
        [
            // Employees
            ...Array(holders.length).fill(humanResources.address),
            // CAO Parameters
            caoParameters.address,
            caoParameters.address,
            // Incentives
            ...Array(incentivesToRegister.length).fill(incentivesManager.address),
        ],
        [
            // Employees
            ...holders.map((holder) =>
                humanResources.interface.encodeFunctionData("addEmployee", [
                    holder.address,
                    ethers.utils.parseEther("0.00001"), // remuneration per block
                ])
            ),
            // CAO Parameters
            caoParameters.interface.encodeFunctionData("setReserveTokensOracles", [
                [config.tokens.BUSD.address],
                [config.tokens.BUSD.pricing.address],
            ]),
            caoParameters.interface.encodeFunctionData("addFundTokens", [[fundToken.address]]),
            // Incentives
            ...Object.entries(incentivesToRegister).map(([_, incentive]) =>
                incentivesManager.interface.encodeFunctionData("addIncentive", [incentive])
            ),
        ],
        [...Array(holders.length).fill(0), 0, 0, ...Array(incentivesToRegister.length).fill(0)]
    );
    console.log("Initial Setup (Main Fund) - Updated Initial CAO States");

    // Log the deployment gas details
    console.log(`CAO Deployment Gas Used: ${caoDeployTxn.gasUsed}`);
    console.log(`CAOParameters Deployment Gas Used: ${caoParametersDeployTxn.gasUsed}`);
    console.log(`HumanResources Deployment Gas Used: ${humanResourcesDeployTxn.gasUsed}`);
    console.log(`Fund Deployment Gas Used: ${fundDeployTxn.gasUsed}`);
    console.log(`OpsGovernor Deployment Gas Used: ${opsGovernorDeployTxn.gasUsed}`);
    console.log(`Pancakeswap LP Farming Util Deployment Gas Used: ${pancakeswapLpFarmingUtilDeployTxn.gasUsed}`);
    console.log(`FundToken Deployment Gas Used: ${fundTokenDeployTxn.gasUsed}`);
    console.log(`FrontOfficeParameters Deployment Gas Used: ${frontOfficeParametersDeployTxn.gasUsed}`);
    console.log(`FrontOffice Deployment Gas Used: ${frontOfficeDeployTxn.gasUsed}`);
    console.log(`Accounting Deployment Gas Used: ${accountingDeployTxn.gasUsed}`);
    console.log(`IncentivesManager Deployment Gas Used: ${incentivesManagerDeployTxn.gasUsed}`);
    console.log(`ReferralIncentive Deployment Gas Used: ${referralIncentiveDeployTxn.gasUsed}`);
    console.log(`Initial Deposit Gas Used: ${initialDepositTxn.gasUsed}`);
    console.log(
        `Total Gas Used: ${caoDeployTxn.gasUsed
            .add(caoParametersDeployTxn.gasUsed)
            .add(humanResourcesDeployTxn.gasUsed)
            .add(fundDeployTxn.gasUsed)
            .add(opsGovernorDeployTxn.gasUsed)
            .add(pancakeswapLpFarmingUtilDeployTxn.gasUsed)
            .add(fundTokenDeployTxn.gasUsed)
            .add(frontOfficeParametersDeployTxn.gasUsed)
            .add(frontOfficeDeployTxn.gasUsed)
            .add(accountingDeployTxn.gasUsed)
            .add(incentivesManagerDeployTxn.gasUsed)
            .add(referralIncentiveDeployTxn.gasUsed)
            .add(initialDepositTxn.gasUsed)}`
    );

    const addresessOutput = {
        cao: cao.address,
        cao_parameters: caoParameters.address,
        human_resouces: humanResources.address,
        fund: fund.address,
        ops_governor: opsGovernor.address,
        utils: Object.entries(utils).reduce((current, [name, each]) => ({ ...current, [name]: each.address }), {}),
        fund_token: fundToken.address,
        front_office_parameters: frontOfficeParameters.address,
        front_office: frontOffice.address,
        accounting: accounting.address,
        incentives_manager: incentivesManager.address,
        incentives: Object.entries(incentives).reduce(
            (current, [name, each]) => ({ ...current, [name]: each.address }),
            {}
        ),
    };

    const dir = "outputs/bsc-mainnet/";
    !fs.existsSync(dir) && fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(dir + "addresses.yaml", yaml.dump(addresessOutput));
};
