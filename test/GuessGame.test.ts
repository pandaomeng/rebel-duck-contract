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

describe("Guess Game", function () {
  let usdc: MockERC20;
  let guessGame: GuessGame;
  let guessGameFactory: GuessGameFactory;
  let admin: SignerWithAddress;
  let alice: SignerWithAddress;

  before("deploy", async () => {
    [admin, alice] = await ethers.getSigners();

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

    const tx = await guessGameFactory
      .connect(admin)
      .createGame(usdc.address, 1701648000, 86400, 4);
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
      [150, 120, 100, 80]
    );
  });

  // expect the guessGame's start time is the next monday's 00:00:00 and the end time is the next Saturday's 00:00:00
  it("should start and end time is correct", async () => {
    const nextMonday = 1701648000;
    const nextFriday = 1701648000 + 4 * 24 * 60 * 60;
    expect(await guessGame.START_TIME()).to.eq(
      nextMonday,
      "the start time should be the next Monday"
    );
    expect(await guessGame.END_TIME()).to.eq(
      nextFriday,
      "the end time should be the next Saturday"
    );
  });

  // alice stake 1000 usdc for number 786, should success
  it("should stake success", async () => {
    const alice = admin;
    const stakeAmount = parseUnits("1000", 18);
    const stakeNumber = 786;
    // print the balance of alice and the allowance of guessGame
    console.log(
      "alice usdc balance: ",
      formatUnits(await usdc.balanceOf(alice.address), 18)
    );
    await usdc.connect(alice).approve(guessGame.address, stakeAmount);
    console.log(
      "guessGame usdc allowance: ",
      formatUnits(await usdc.allowance(alice.address, guessGame.address), 18)
    );

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
    ).to.eq(stakeAmount, "the stake amount should be 1000");
  });
});
