import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFTEnumerable", function () {
  it("Should work successfully", async function () {
    return
    // const NFTEnumerable = await ethers.getContractFactory("NFTEnumerable");
    // const nftReader = await NFTEnumerable.deploy();

    const nftReader = await ethers.deployContract("NFTEnumerable");

    await nftReader.waitForDeployment();

    console.log('deployed')
    const res = await nftReader.tokensDetailOfOwner('0x20C882CE280c7c05cF8a99B257a9C927414210C5', '0x3c76bfC17701d325AD340D0E5f56F402A1182250', 2000)

    console.log('res: ', res)

    // wait until the transaction is mined
  });
});
