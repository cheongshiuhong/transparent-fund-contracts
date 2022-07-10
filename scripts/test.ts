// Libraries
import { ethers } from "hardhat";

/** Main function */
async function main() {
    const signers = await ethers.getSigners();

    const BaseFund = await ethers.getContractFactory("BaseFund");
    const baseFund = await BaseFund.deploy();
    await baseFund.deployed();

    // Deploy the ops governor
    const OpsGovernor = await ethers.getContractFactory("OpsGovernor");
    const opsGovernor = await OpsGovernor.deploy(
        baseFund.address,
        [signers[0].address, signers[1].address],
        [signers[2].address, signers[3].address]
    );
    await opsGovernor.deployed();

    // Set the reference to the ops governor contract
    await (await baseFund.setOpsGovernor(opsGovernor.address)).wait();

    // Create a proposal
    const tokensAddresses = [signers[0].address, signers[1].address];
    const response = await (
        await opsGovernor
            .connect(signers[0])
            .createProposal(
                "Initial registration of tokens",
                100,
                opsGovernor.interface.encodeFunctionData("registerTokens", [tokensAddresses])
            )
    ).wait();

    const proposalId = response.events[0].args[0].toNumber();

    // All vote in approval
    const managers = [signers[0], signers[1]];
    await Promise.all(
        managers.slice(1).map(async (manager) => await (await opsGovernor.connect(manager).vote(proposalId, 0)).wait())
    );

    // Execute the proposal
    await (await opsGovernor.connect(managers[0]).executeProposal(proposalId)).wait();

    const tokens = await opsGovernor.getRegisteredTokens();
    console.log("registered:", tokens);

    // const activeProposals = await opsGovernor.getActiveProposals();

    // console.log("Active proposals", activeProposals[0]);
    // console.log("Active proposals", activeProposals[0][0]);
    // console.log("Active proposals", activeProposals[0][1]);
    // console.log("Response", response);
    // console.log("Response logs topics", response.logs.topics);
    // console.log("Events", response.events.args);
    // console.log("Events", response.events.decode);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
