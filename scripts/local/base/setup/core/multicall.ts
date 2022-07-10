// Types
import type { ContractsState } from "../../interfaces";

// Libraries
import { ethers } from "hardhat";

/** Setup erc20 tokens and their oracles for use */
export default async (state: ContractsState): Promise<ContractsState> => {
    console.log("--- bsc > setup > core > multicall > start ---");

    const Multicall = await ethers.getContractFactory("Multicall2");

    const multicall = await Multicall.deploy();
    await multicall.deployed();

    console.log("--- bsc > setup > core > multicall > done ---");

    return { ...state, multicall };
};
