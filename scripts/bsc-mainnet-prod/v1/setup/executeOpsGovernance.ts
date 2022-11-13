// Types
import type { Contract } from "ethers";

/** Executes through creating proposal and voting then executing */
const executeOpsGovernance = async (opsGovernor: Contract, callData: string): Promise<void> => {
    await (await opsGovernor.createProposal("Proposal", 1_000_000, callData)).wait();
    // const proposalId = receipt.events[0].args[0].toNumber();

    // // All to vote in approval
    // await Promise.all(
    //     managers.slice(1).map(async (manager) => await (await opsGovernor.connect(manager).vote(proposalId, 0)).wait())
    // );

    // // Execute the proposal
    // await (await opsGovernor.connect(managers[0]).executeProposal(proposalId)).wait();
};

export default executeOpsGovernance;
