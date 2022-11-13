// Libraries
import { ethers } from "hardhat";

/** Main function */
async function main() {
    const cao = (await ethers.getContractFactory("CAO")).attach("0x3456f6adF87A702318A10C6324402a5944E9dF1b");
    const caoTokenAddress = await cao.getCAOTokenAddress();
    console.log("caoTokenAddress:", caoTokenAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
