// Libraries
import { ethers } from "hardhat";

const main = async () => {
    const [deployer] = await ethers.getSigners();
    console.log("Deployer:", deployer.address);
    const FrontOffice = await ethers.getContractFactory("FrontOffice");
    console.log("Deploying...");
    const frontOffice = await FrontOffice.connect(deployer).deploy(
        "0x45E017b467a38f5D83094e60a1494d19655bec22",
        "0x69D177d99B6550bb8d6bc9E800dBB273f993e42f"
    );
    console.log(`Awaiting confirmation @ ${frontOffice.address}`);
    const txn = await (await frontOffice.deployed()).deployTransaction.wait();
    console.log(`Deployed [FrontOffice] @ ${frontOffice.address} for ${txn.gasUsed} gas.`);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
