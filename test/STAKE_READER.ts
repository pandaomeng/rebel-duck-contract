import { expect } from "chai";
import { ethers } from "hardhat";

describe("Stake Reader", function () {
  it("Should work successfully", async function () {
    // const NFTEnumerable = await ethers.getContractFactory("NFTEnumerable");
    // const nftReader = await NFTEnumerable.deploy();

    const stakeReader = await ethers.deployContract("StakeReader");

    await stakeReader.waitForDeployment();

    console.log('deployed')
    const res = await stakeReader.stakedNftsOfOwner('0x20C882CE280c7c05cF8a99B257a9C927414210C5', '0xeE4327b2fa194e4c5DBE04d8b78A63717bB423F2', '0x3c76bfC17701d325AD340D0E5f56F402A1182250')
    console.log('stakedLList: ', res)


    const res2 = await stakeReader.calcAllReward('0x20C882CE280c7c05cF8a99B257a9C927414210C5', '0xeE4327b2fa194e4c5DBE04d8b78A63717bB423F2')
    console.log('calcAllReward: ', res2)

    // wait until the transaction is mined
  });
});
