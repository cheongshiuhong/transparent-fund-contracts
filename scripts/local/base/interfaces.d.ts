import type { Contract } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

export type Token = {
    token: Contract;
    chainlinkOracle: Contract;
};

export type PancakeswapProtocols = {
    cakeToken: Contract;
    cakeTokenOracle: Contract;
    syrupBar: Contract;
    masterChef: Contract;
    masterChefV2: Contract;
    // Single token pools
    cakePool: Contract;
    smartChefFactory: Contract;
    pools: {
        pool: Contract;
        underlying: Contract;
    }[];
    // Swaps & Liquidities
    router: Contract;
    pairFactory: Contract;
    pairs: {
        underlyingA: Contract;
        underlyingB: Contract;
        pair: Contract;
    }[];
    // Off-chain reference
    pidsMapper: Record<string, number>;
};

export type VenusProtocols = {
    comptrollerG5: Contract;
    xvs: Contract;
    xvsOracle: Contract;
    lens: Contract;
    lendingPools: {
        underlying: Contract;
        pool: Contract;
    }[];
};

export type Protocols = {
    pancakeswap?: PancakeswapProtocols;
    venus?: VenusProtocols;
};

export type BaseFund = {
    fund: Contract;
    opsGovernor: Contract;
    roles: {
        managers: SignerWithAddress[];
        operators: SignerWithAddress[];
    };
    utils: {
        pancakeswapLpFarmingUtil: Contract;
    };
};

export type ContractsState = {
    NUM_TOKENS: number;
    signers: SignerWithAddress[];
    multicall?: Contract;
    tokens?: Token[];
    protocols?: Protocols;
    baseFund?: BaseFund;
};
