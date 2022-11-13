import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import "solidity-coverage";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (_taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * BSC Main-Net:  https://bsc-dataseed.binance.org/
 * BSC Test-Net:  https://data-seed-prebsc-1-s1.binance.org:8545
 * ETH Main-Net:  https://mainnet.infura.io/v3/
 * AVAX Main-Net: https://api.avax.network/ext/bc/C/rpc
 */

const config: HardhatUserConfig = {
    solidity: {
        // Older versions for deploying the protocols locally
        compilers: [{ version: "0.8.12" }, { version: "0.6.12" }, { version: "0.5.16" }],
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            // Needed to deploy the protocols
            allowUnlimitedContractSize: true,
            gasPrice: 5 * 10 ** 9,
        },
        localhost: {
            // Needed to deploy the protocols
            allowUnlimitedContractSize: true,
            // accounts: [process.env.DEPLOYER_PRIVATE_KEY || "", process.env.TESTER_PRIVATE_KEY || ""],
        },
        // "bsc-testnet": {
        //     url: "https://data-seed-prebsc-1-s1.binance.org:8545",
        //     gasPrice: 10 * 10 ** 9,
        //     accounts: [
        //         process.env.DEPLOYER_PRIVATE_KEY || "",
        //         process.env.HOT_OWNER_PRIVATE_KEY || "",
        //         process.env.MANAGER_PRIVATE_KEY || "",
        //     ],
        // },
        // "bsc-mainnet-qa": {
        //     url: "https://bsc-dataseed.binance.org/",
        //     gasPrice: 5 * 10 ** 9,
        //     accounts: [process.env.DEPLOYER_PRIVATE_KEY || "", process.env.TESTER_PRIVATE_KEY || ""],
        // },
        "bsc-mainnet": {
            url: "https://bsc-dataseed.binance.org/",
            gasPrice: 5 * 10 ** 9,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY || ""],
        },
    },
    paths: {
        sources: "./src",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
    },
};

export default config;

module.exports = {
    mocha: {
        timeout: 1_000_000, // ms
    },
};
