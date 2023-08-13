import { ethers } from "hardhat";

async function main() {
  const stakeReader = await ethers.deployContract("StakeReader");

  await stakeReader.waitForDeployment();

  console.log(
    `deployed to ${stakeReader.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
