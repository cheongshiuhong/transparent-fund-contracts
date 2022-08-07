// Types
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Contract } from "ethers";

/** Executes through creating proposal and voting then executing */
const executeOpsGovernance = async (
    opsGovernor: Contract,
    managers: SignerWithAddress[],
    callData: string
): Promise<void> => {
    const receipt = await (await opsGovernor.connect(managers[0]).createProposal("A proposal", 1_000, callData)).wait();
    const proposalId = receipt.events[0].args[0].toNumber();

    // All to vote in approval
    await Promise.all(
        managers.slice(1).map(async (manager) => await (await opsGovernor.connect(manager).vote(proposalId, 0)).wait())
    );

    // Execute the proposal
    await (await opsGovernor.connect(managers[0]).executeProposal(proposalId)).wait();
};

export default executeOpsGovernance;
