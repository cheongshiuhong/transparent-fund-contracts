// Libraries
import { ethers } from "hardhat";

/** Main function */
async function main() {
    const signers = await ethers.getSigners();

    console.log("Deploying CAO...");
    const CAO = await ethers.getContractFactory("CAO");
    const cao = await CAO.deploy(
        signers[0].address,
        "Material",
        "MTRL",
        [signers[0].address],
        [ethers.utils.parseEther("10000")]
    );
    await cao.deployed();

    // Delegate the token's voting right to self
    console.log("Delegating...");
    const CAOToken = await ethers.getContractFactory("CAOToken");
    const caoToken = CAOToken.attach(await cao.getTokenAddress());
    await (await caoToken.connect(signers[0]).delegate(signers[0].address)).wait();

    // Create a proposal
    console.log("Creating proposal...");
    const response = await (
        await cao
            .connect(signers[0])
            .createProposal(
                "Proposal",
                0,
                1200,
                [cao.address],
                [
                    cao.interface.encodeFunctionData("setReserveTokensOracles", [
                        [signers[0].address],
                        [signers[0].address],
                    ]),
                ],
                [0]
            )
    ).wait();
    console.log("proposal response", response);

    // Voting on the proposal
    console.log("Voting...");
    await (await cao.connect(signers[0]).vote(0, 0, "I like")).wait();

    // Executing the proposal
    console.log("Executing the proposal...");
    await (await cao.connect(signers[0]).executeProposal(0)).wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
