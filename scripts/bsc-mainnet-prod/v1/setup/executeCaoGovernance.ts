// Types
// import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Contract } from "ethers";

/** Executes through creating proposal and voting then executing */
const executeCaoGovernance = async (
    cao: Contract,
    callAddresses: string[],
    callDatas: string[],
    callValues: number[]
): Promise<void> => {
    await (await cao.createProposal("Proposal", 100, 1_000_000, callAddresses, callDatas, callValues)).wait();
    // const proposalId = receipt.events[0].args[0].toNumber();

    // // All to vote in approval
    // await Promise.all(
    //     holders.map(async (holder) => await (await cao.connect(holder).vote(proposalId, 0, "vote")).wait())
    // );

    // // Execute the proposal
    // await (await cao.connect(holders[0]).executeProposal(proposalId, { gasLimit: 5_000_000 })).wait();
};

export default executeCaoGovernance;
