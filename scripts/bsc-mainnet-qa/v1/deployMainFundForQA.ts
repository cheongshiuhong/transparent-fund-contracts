// Libraries
// import { ethers } from "hardhat";

// Code
import deploy from "./deploy";

/** Main function */
async function main() {
    // const state = { signers: await ethers.getSigners(), NUM_TOKENS: 3 };
    return await deploy();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
