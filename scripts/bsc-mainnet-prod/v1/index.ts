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

const teamAddresses = [
    "0x427e93EA78674eDcAB47271B59D5d826b1727aC5",
    "0x5608950a47644958632B1036CF22D2965b0C9AE2",
    "0x5DCb356cf1b1C71A500Ed1Df23E0678fDb2bCfed",
];
const addrOperator = "0x07FB31846AEaa463E5576b3c817a1D7d6509F4fA";
const addrRunner = "0x07FB31846AEaa463E5576b3c817a1D7d6509F4fA";

/** Main function */
async function main() {
    const [deployer] = await ethers.getSigners();
    const state: DeploymentState = {
        deployer,
        holdersAddresses: [...teamAddresses],
        managersAddresses: [deployer.address, ...teamAddresses],
        operatorsAddresses: [addrOperator],
        taskRunnerAddress: addrRunner,
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
