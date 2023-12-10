import { expect, use } from "chai";
import chaiAsPromised from "chai-as-promised";
import { ethers, network, upgrades } from "hardhat";
// eslint-disable-next-line camelcase
import { GuessGame, GuessGameFactory, MockERC20 } from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import { ERC20 } from "../typechain/ERC20";
import moment from "moment";

use(chaiAsPromised);

const START_TIME = moment().unix();
const INTERVAL = 24 * 60 * 60;
const INTERVAL_NUMS = 4;
const WEIGHTS = [150, 120, 100, 80];

describe("Guess Game", function () {
  let usdc: MockERC20;
  let guessGame: GuessGame;
  let guessGameFactory: GuessGameFactory;
  let admin: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  before("deploy", async () => {
    [admin, alice, bob] = await ethers.getSigners();

    const GuessGameFactory = await ethers.getContractFactory(
      "GuessGameFactory"
    );
    guessGameFactory = (await upgrades.deployProxy(
      GuessGameFactory,
      [admin.address],
      {
        initializer: "initialize",
      }
    )) as GuessGameFactory;
    await guessGameFactory.deployed();

    const GuessGame = await ethers.getContractFactory("GuessGame");
    guessGame = await GuessGame.connect(admin).deploy();
    await guessGameFactory.setImplementation(guessGame.address, true);

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    usdc = (await MockERC20.connect(admin).deploy(
      "MockERC20",
      "Mock"
    )) as MockERC20;
    await usdc.connect(admin).mint(alice.address, parseUnits("1000000", 18));
    await usdc.connect(admin).mint(bob.address, parseUnits("1000000", 18));

    const tx = await guessGameFactory
      .connect(admin)
      .createGame(usdc.address, START_TIME, INTERVAL, INTERVAL_NUMS);
    const res = await tx.wait();
    expect(res.events).to.not.eq(
      undefined,
      "After creating Factory, the events should not be empty."
    );
    if (!res.events) return;

    const event = res.events.find(
      (event) => event.event === "GuessGameCreated"
    );

    expect(event).to.not.eq(
      undefined,
      "After creating GuessGame, the guessGameCreated event should not be empty."
    );
    if (!event || !event.args) return;

    const guessGameAddress = event.args[1];
    expect(guessGameAddress).to.not.eq(
      undefined,
      "After creating GuessGame, the guessGameAddress should not be undefined."
    );

    guessGame = guessGame.attach(guessGameAddress);

    expect(await guessGame.TOKEN_ADDRESS()).to.eq(usdc.address);

    // set weights for game
    await guessGameFactory.setWeightsForGame(
      guessGame.address,
      WEIGHTS
    );
  });

  // expect the guessGame's start time is the next monday's 00:00:00 and the end time is the next Saturday's 00:00:00
  it("should start and end time is correct", async () => {
    const nextMonday = START_TIME
    const nextFriday = START_TIME + INTERVAL_NUMS * INTERVAL;
    expect(await guessGame.START_TIME()).to.eq(
      nextMonday,
      "the start time should be the next Monday"
    );
    expect(await guessGame.END_TIME()).to.eq(
      nextFriday,
      "the end time should be the next Saturday"
    );
  });

  // alice stake 500 usdc for number 786, should success
  it("should stake success", async () => {
    const stakeAmount = parseUnits("500", 18);
    const stakeNumber = 786;
    // print the balance of alice and the allowance of guessGame
    await usdc.connect(alice).approve(guessGame.address, stakeAmount.mul(10));

    const tx = await guessGame
      .connect(alice)
      .chooseNumberAndStake(stakeNumber, stakeAmount);
    const res = await tx.wait();
    expect(res.events).to.not.eq(
      undefined,
      "After staking, the events should not be empty."
    );
    if (!res.events) return;

    const event = res.events.find((event) => event.event === "ChooseAndStake");

    expect(event).to.not.eq(
      undefined,
      "After staking, the stake event should not be empty."
    );
    if (!event || !event.args) return;

    expect(await guessGame.userChosenNumbers(alice.address, 0)).to.eq(
      stakeNumber,
      "the stake number should be 786"
    );
    expect(
      await guessGame.userStakedAmountPerNumber(alice.address, stakeNumber)
    ).to.eq(stakeAmount, "the stake amount should be 500");

    // const history = await guessGame.getUserOperationHistories(alice.address);
    // console.log("history: ", history);
  });

  // alice stake 500 usdc for number 786 again, should success, and the stake amount should be 1000
  it("should stake success again", async () => {
    const stakeAmount = parseUnits("500", 18);
    const stakeNumber = 786;
    const tx = await guessGame
      .connect(alice)
      .chooseNumberAndStake(stakeNumber, stakeAmount);
    const res = await tx.wait();
    expect(res.events).to.not.eq(
      undefined,
      "After staking, the events should not be empty."
    );
    if (!res.events) return;

    const event = res.events.find((event) => event.event === "ChooseAndStake");

    expect(event).to.not.eq(
      undefined,
      "After staking, the stake event should not be empty."
    );
    if (!event || !event.args) return;

    expect(await guessGame.userChosenNumbers(alice.address, 0)).to.eq(
      stakeNumber,
      "the stake number should be 786"
    );
    expect(
      await guessGame.userStakedAmountPerNumber(alice.address, stakeNumber)
    ).to.eq(parseUnits("1000", 18), "the stake amount should be 1000");

    // alice's share should be 1000 * WEIGHT[0]
    expect(await guessGame.userStakedSharePerNumber(alice.address, stakeNumber)).to.eq(
      parseUnits("1000", 18).mul(WEIGHTS[0]),
      `the share should be ${parseUnits("1000", 18).mul(WEIGHTS[0])}`
    );
  });

  // the time pass 1 day, alice stake 500 usdc for number 786 again, should success, and the stake amount should be 1500
  it("should stake success again after one day", async () => {
    const stakeAmount = parseUnits("500", 18);
    const stakeNumber = 786;
    await network.provider.send("evm_increaseTime", [24 * 60 * 60]);
    await network.provider.send("evm_mine");

    const tx = await guessGame
      .connect(alice)
      .chooseNumberAndStake(stakeNumber, stakeAmount);
    const res = await tx.wait();
    expect(res.events).to.not.eq(
      undefined,
      "After staking, the events should not be empty."
    );
    if (!res.events) return;

    const event = res.events.find((event) => event.event === "ChooseAndStake");

    expect(event).to.not.eq(
      undefined,
      "After staking, the stake event should not be empty."
    );
    if (!event || !event.args) return;

    expect(await guessGame.userChosenNumbers(alice.address, 0)).to.eq(
      stakeNumber,
      "the stake number should be 786"
    );
    expect(
      await guessGame.userStakedAmountPerNumber(alice.address, stakeNumber)
    ).to.eq(parseUnits("1500", 18), "the stake amount should be 1500");

    
    const aliceStakedShares = parseUnits("1000", 18).mul(WEIGHTS[0]).add(parseUnits("500", 18).mul(WEIGHTS[1]))
    expect(await guessGame.userStakedSharePerNumber(alice.address, stakeNumber)).to.eq(
      aliceStakedShares,
      `aliceStakedShares`
    );
  });

  // in day 1, bob stake 800 usdc for number 324, should success
  it("should stake success in day 1", async () => {
    const stakeAmount = parseUnits("800", 18);
    const stakeNumber = 324;
    await usdc.connect(bob).approve(guessGame.address, stakeAmount);
    const tx = await guessGame
      .connect(bob)
      .chooseNumberAndStake(stakeNumber, stakeAmount);
    const res = await tx.wait();
    expect(res.events).to.not.eq(
      undefined,
      "After staking, the events should not be empty."
    );
    if (!res.events) return;

    const event = res.events.find((event) => event.event === "ChooseAndStake");

    expect(event).to.not.eq(
      undefined,
      "After staking, the stake event should not be empty."
    );
    if (!event || !event.args) return;

    expect(await guessGame.userChosenNumbers(bob.address, 0)).to.eq(
      stakeNumber,
      "the stake number should be 324"
    );
    expect(
      await guessGame.userStakedAmountPerNumber(bob.address, stakeNumber)
    ).to.eq(stakeAmount, "the stake amount should be 800");

    const bobStakedShares = parseUnits("800", 18).mul(WEIGHTS[1])
    expect(await guessGame.userStakedSharePerNumber(bob.address, stakeNumber)).to.eq(
      bobStakedShares,
      `bobStakedShares`
    );
  });

  // pass 2 days, should not be able to set FinalNumber
  it("should not be able to get FinalNumber", async () => {
    await network.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]);
    await network.provider.send("evm_mine");
    await expect(guessGameFactory.connect(admin).setFinalNumber(guessGame.address)).to.be.revertedWith(
      "GuessGame: NOT_IN_OPEN_TIME"
    );
  });

  // pass 1 day, should be able to set FinalNumber
  it("should be able to get FinalNumber", async () => {
    await network.provider.send("evm_increaseTime", [1 * 24 * 60 * 60]);
    await network.provider.send("evm_mine");
    const tx = await guessGameFactory.connect(admin).setFinalNumber(guessGame.address);
    
    // 786 
    const aliceStakedShares = parseUnits("1000", 18).mul(WEIGHTS[0]).add(parseUnits("500", 18).mul(WEIGHTS[1]))

    // 324
    const bobStakedShares = parseUnits("800", 18).mul(WEIGHTS[1])

    const averageNumber = aliceStakedShares.mul(786).add(bobStakedShares.mul(324)).div(aliceStakedShares.add(bobStakedShares))
    console.log(`FINAL_NUMBER: ${await guessGame.FINAL_NUMBER()}`)
    console.log(`AVERAGE_NUMBER: ${await guessGame.AVERAGE_NUMBER()}`)

    // console.log('await getStakedNumberInfos: ', await guessGame.getStakedNumberInfos())

    // AVERAGE_NUMBER should be ${averageNumber}
    expect(await guessGame.AVERAGE_NUMBER()).to.eq(
      averageNumber,
      `AVERAGE_NUMBER should be ${averageNumber}`
    );

    expect(await guessGame.FINAL_NUMBER()).to.lte(
      averageNumber.add(100),
      "the final number should be less than averageNumber + 100"
    );

    expect(await guessGame.FINAL_NUMBER()).to.gte(
      averageNumber.sub(100),
      "the final number should be greater than averageNumber - 100"
    );
  });


  // test getStakedNumberInfos
  it("should getStakedNumberInfos", async () => {
    const infos = await guessGame.getStakedNumberInfos()
    console.log('infos: ', infos, null, 2)
  });
});
