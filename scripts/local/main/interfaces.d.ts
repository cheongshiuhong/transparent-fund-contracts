import type { Contract } from "ethers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { BigNumber } from "@ethersproject/bignumber";

export type Token = {
    token: Contract;
    chainlinkOracle: Contract;
};

export type MainFund = {
    fund: Contract;
    roles: {
        holders: SignerWithAddress[];
        managers: SignerWithAddress[];
        operators: SignerWithAddress[];
        taskRunner: SignerWithAddress;
    };
    opsGovernor: Contract;
    fundToken: Contract;
    cao: Contract;
    caoToken: Contract;
    humanResources: Contract;
    accounting: Contract;
    frontOffice: Contract;
    incentivesManager: Contract;
    incentives: Record<string, Contract>;
};

export type ContractsState = {
    NUM_TOKENS: number;
    signers: SignerWithAddress[];
    tokens?: Token[];
    mainFund?: MainFund;
};

export type AccountingState = {
    aumValue: BigNumber;
    periodBeginningBlock: BigNumber;
    periodBeginningAum: BigNumber;
    periodBeginningSupply: BigNumber;
    theoreticalSupply: BigNumber;
};
