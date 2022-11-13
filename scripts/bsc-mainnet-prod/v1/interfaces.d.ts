import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { TransactionReceipt } from "@ethersproject/abstract-provider";
import type { Contract } from "ethers";
import type { BigNumber } from "@ethersproject/bignumber";

/* eslint-disable camelcase */

export type TokenConfig = {
    address: string;
    decimals: number;
    pricing: { address: string };
};

export type TokensConfig = Record<string, TokenConfig>;

export type PancakeswapConfig = {
    cake_pool: string;
    smart_chefs: Record<string, string>;
    master_chef_v2: string;
    router: string;
    pairs: Record<string, { address: string }>;
};

export type VenusConfig = {
    unitroller: string;
    lens: string;
    pools: Record<string, string>;
};

export type Config = {
    tokens: TokensConfig;
    pancakeswap: PancakeswapConfig;
    venus: VenusConfig;
};

/** eslint-disable camelcase */
type DeploymentState = {
    deployer: SignerWithAddress;
    holdersAddresses: string[];
    managersAddresses: string[];
    operatorsAddresses: string[];
    taskRunnerAddress: string;
    config: Config;
    contracts: Record<string, Contract>;
    deployTxns: Record<string, TransactionReceipt | null>;
    runningGasCost: BigNumber;
};
