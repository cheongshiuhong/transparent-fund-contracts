// Types
import type { Contract } from "ethers";
import type { ContractsState } from "../../interfaces";

// Libraries
import { ethers } from "hardhat";

// Code
import helpers from "../../helpers";

/** Deploy a new jump rate model with arbitrary params */
const deployJumpRateModel = async (): Promise<Contract> => {
    const JumpRateModel = await ethers.getContractFactory("JumpRateModel");
    const jumpRateModel = await JumpRateModel.deploy(
        5 * helpers.decimals(15), // baseRatePerYear
        2 * helpers.decimals(15), // multiplierPerYear
        2 * helpers.decimals(15), // jumpMultiplierPerYear
        5 // kink - utilization jump point
    );
    await jumpRateModel.deployed();
    return jumpRateModel;
};

/** Setup venus lending protocol and lending pools */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.tokens) return state;

    console.log("--- bsc > setup > protocols > venus > start ---");

    // Deploy the XVS token (mint all to first signer first)
    const XVS = await ethers.getContractFactory("XVS");
    const xvs = await XVS.deploy(state.signers[0].address);
    await xvs.deployed();

    // Deploy Comptroller
    // Comptroller is shared to assess user-risk across all pools
    const ComptrollerG5 = await ethers.getContractFactory("ComptrollerG5");
    const comptrollerG5 = await ComptrollerG5.deploy(xvs.address);
    await comptrollerG5.deployed();

    // Set Price Oracle for Comptroller
    const PriceOracle = await ethers.getContractFactory("PriceOracleProxy");
    const priceOracle = await PriceOracle.deploy();
    await priceOracle.deployed();

    // Register price oracle with comptroller
    await (await comptrollerG5._setPriceOracle(priceOracle.address)).wait();

    // Deploy the Venus Lens
    const VenusLens = await ethers.getContractFactory("VenusLens");
    const lens = await VenusLens.deploy();
    await lens.deployed();

    // Deploy the BNB lending pool first
    const jumpRateModel = await deployJumpRateModel();
    const VBNB = await ethers.getContractFactory("VBNB");
    const vBnb = await VBNB.deploy(
        comptrollerG5.address,
        jumpRateModel.address,
        ethers.utils.parseEther("1"),
        "Native BNB Coins",
        "BNB",
        18,
        state.signers[0].address
    );
    await vBnb.deployed();
    // Add the market and set the collateral factor
    await (await comptrollerG5._supportMarket(vBnb.address)).wait();
    await (await comptrollerG5._setCollateralFactor(vBnb.address, ethers.utils.parseEther("0.8"))).wait();

    // Deposit some BNB to provide some liquidity into the lending pool
    const amount = ethers.utils.parseEther("100"); // 100 ethers
    await helpers.sendEth(state.signers[0], vBnb.address, amount);

    // Iterate and create pools for each token (exclued WBNB since Venus uses the real BNB)
    const lendingPools: NonNullable<NonNullable<ContractsState["protocols"]>["venus"]>["lendingPools"] = [
        { underlying: state.tokens[0].token, pool: vBnb },
    ];
    for (let i = 1; i < state.tokens.length; i++) {
        const underlying = state.tokens[i].token;

        // Deploy VBep20 (Immutable) lending pool
        // Need to use VBep20Delegator
        const jumpRateModel = await deployJumpRateModel();
        const VBep20 = await ethers.getContractFactory("VBep20Immutable");
        const pool = await VBep20.deploy(
            underlying.address,
            comptrollerG5.address,
            jumpRateModel.address,
            ethers.utils.parseEther("1"),
            `Token ${i}`,
            `TKN${i}`,
            18,
            state.signers[0].address
        );
        await pool.deployed();

        // Add the market and set the collateral factor
        await (await comptrollerG5._supportMarket(pool.address)).wait();
        await (await comptrollerG5._setCollateralFactor(pool.address, ethers.utils.parseEther("0.8"))).wait();

        // Give allowance
        await (await underlying.connect(state.signers[0]).approve(pool.address, amount)).wait();

        // Deposit some tokens to provide some liquidity in the lending pool
        await (await pool.connect(state.signers[0]).mint(amount)).wait();

        lendingPools.push({ underlying, pool });
    }

    console.log("--- bsc > setup > protocols > venus > done ---");

    return {
        ...state,
        protocols: {
            ...(state.protocols || {}),
            venus: { comptrollerG5, xvs, lens, lendingPools },
        },
    };
};
