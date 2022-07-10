// Libraries
import { ethers } from "hardhat";

// Code
import setup from "./setup";
import deploy from "./deploy";
import output from "./output";

/** Main function */
async function main() {
    const state = { signers: await ethers.getSigners(), NUM_TOKENS: 3 };
    return setup(state).then(deploy).then(output);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
