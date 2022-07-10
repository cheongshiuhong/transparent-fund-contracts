// Types
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { TransactionReceipt } from "@ethersproject/abstract-provider";
import { BigNumber } from "@ethersproject/bignumber";
import { Contract } from "ethers";

// Libraries
import { ethers } from "hardhat";

/** Helpers */
export default {
    decimals: (n: number): number => 10 ** n,
    sendEth: async (signer: SignerWithAddress, to: string, value: BigNumber): Promise<TransactionReceipt> =>
        await (await signer.sendTransaction({ to, value })).wait(),
    getEthBalance: async (signer: SignerWithAddress | Contract): Promise<BigNumber> =>
        await ethers.provider.getBalance(signer.address),
    getBlock: async (): Promise<number> => await ethers.provider.getBlockNumber(),
    getBlockTimestamp: async (): Promise<number> =>
        (await ethers.provider.getBlock(ethers.provider.getBlockNumber())).timestamp,
    getBlockTimestampWithDelay: async (delaySeconds: number): Promise<number> =>
        (await ethers.provider.getBlock(ethers.provider.getBlockNumber())).timestamp + delaySeconds,
};
