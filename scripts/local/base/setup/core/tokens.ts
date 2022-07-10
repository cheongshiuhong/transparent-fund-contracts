// Types
import type { ContractsState } from "../../interfaces";

// Libraries
import { ethers } from "hardhat";

/** Setup erc20 tokens and their oracles for use */
export default async (state: ContractsState): Promise<ContractsState> => {
    console.log("--- bsc > setup > core > tokens > start ---");

    const WETH = await ethers.getContractFactory("MockedWETH");
    const ERC20 = await ethers.getContractFactory("MockedERC20");
    const ChainlinkOracle = await ethers.getContractFactory("MockedChainlinkOracle");

    const wEth = await WETH.deploy("Wrapped ETH", "WETH");
    await wEth.deployed();
    const wEthChainlinkOracle = await ChainlinkOracle.deploy("WETH Oracle");
    await wEthChainlinkOracle.deployed();

    // Mint WETH for the signers
    await Promise.all(state.signers.map((signer) => wEth.mint(signer.address, ethers.utils.parseEther("10000"))));

    // Setup some ETH in the WETH contract
    await (await wEth.deposit({ value: ethers.utils.parseEther("100") })).wait();

    // Deploy the tokens and mint some
    const tokens: ContractsState["tokens"] = [{ token: wEth, chainlinkOracle: wEthChainlinkOracle }];
    for (let i = 0; i < state.NUM_TOKENS; i++) {
        // ERC20 token deployment
        const token = await ERC20.deploy(`Token ${i}`, `TKN${i}`);
        await token.deployed();

        // Chainlink token deployment
        const chainlinkOracle = await ChainlinkOracle.deploy(`Token ${i} Oracle`);
        await chainlinkOracle.deployed();

        // Mint tokens for the signers
        await Promise.all(state.signers.map((signer) => token.mint(signer.address, ethers.utils.parseEther("10000"))));

        tokens.push({ token, chainlinkOracle });
    }

    console.log("--- bsc > setup > core > tokens > done ---");

    return { ...state, tokens };
};
