// Types
import type { DeploymentState } from "./interfaces";

// Libraries
import { ethers } from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";

// Code
import loadConfig from "./loadConfig";
import deploy from "./deploy";
import setup from "./setup";
import output from "./output";

/** Main function */
async function main() {
    const [deployer, tester] = await ethers.getSigners();
    const state: DeploymentState = {
        deployer,
        holders: [deployer, tester],
        managers: [deployer, tester],
        managersAddresses: [deployer.address, tester.address],
        operatorsAddresses: [deployer.address, tester.address],
        taskRunnerAddress: tester.address,
        config: loadConfig(),
        contracts: {},
        deployTxns: {},
        runningGasCost: BigNumber.from(0),
    };
    return await deploy(state).then(setup).then(output);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
