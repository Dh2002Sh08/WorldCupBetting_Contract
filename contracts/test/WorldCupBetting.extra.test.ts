import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("WorldCupBetting extra coverage", function () {
  async function deployFixture() {
    const [owner, oracle, alice, bob, buyer] = await ethers.getSigners();

    const ReputationSystem = await ethers.getContractFactory("ReputationSystem");
    const reputationSystem: any = await ReputationSystem.deploy();
    await reputationSystem.waitForDeployment();

    const WorldCupBetting = await ethers.getContractFactory("WorldCupBetting");
    const worldCupBetting: any = await WorldCupBetting.deploy(await reputationSystem.getAddress());
    await worldCupBetting.waitForDeployment();

    await reputationSystem.setPredictionMarket(await worldCupBetting.getAddress());

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const token: any = await MockERC20.deploy("Mock USDC", "mUSDC");
    await token.waitForDeployment();

    return { owner, oracle, alice, bob, buyer, reputationSystem, worldCupBetting, token };
  }

  it("reports market helpers and supports cancelling a listing", async function () {
    const { oracle, alice, worldCupBetting } = await deployFixture();
    const resolution = (await time.latest()) + 3600;

    await worldCupBetting.createMarket(
      "Helper market",
      "Checks helper views",
      ["YES", "NO"],
      resolution,
      oracle.address,
      ethers.ZeroAddress
    );

    const marketId = await worldCupBetting.marketCount();
    expect(await worldCupBetting.getTotalPool(marketId)).to.equal(0n);
    expect(await worldCupBetting.getPrice(marketId, 0)).to.equal(ethers.parseEther("0.5"));

    const stake = ethers.parseEther("0.25");
    await worldCupBetting.connect(alice).placeBet(marketId, 0, stake, stake, { value: stake });

    const betIds = await worldCupBetting.getUserBets(alice.address);
    const marketBetIds = await worldCupBetting.getMarketBets(marketId);

    expect(betIds.length).to.equal(1);
    expect(marketBetIds.length).to.equal(1);
    expect(await worldCupBetting.getTotalPool(marketId)).to.equal(stake);
    expect(await worldCupBetting.getPrice(marketId, 0)).to.equal(ethers.parseEther("1"));

    await worldCupBetting.connect(alice).listPosition(betIds[0], ethers.parseEther("0.3"));
    await worldCupBetting.connect(alice).cancelListing(betIds[0]);

    const bet = await worldCupBetting.bets(betIds[0]);
    expect(bet.listed).to.equal(false);
    expect(bet.listPrice).to.equal(0n);
  });

  it("supports ERC20 secondary sale, claim, and fee withdrawal", async function () {
    const { owner, oracle, alice, bob, buyer, worldCupBetting, token } = await deployFixture();
    const tokenAddress = await token.getAddress();
    const marketAddress = await worldCupBetting.getAddress();
    const resolution = (await time.latest()) + 3600;
    const stake = ethers.parseUnits("100", 18);
    const listPrice = ethers.parseUnits("110", 18);

    await worldCupBetting.createMarket(
      "ERC20 market",
      "Checks token paths",
      ["YES", "NO"],
      resolution,
      oracle.address,
      tokenAddress
    );

    const marketId = await worldCupBetting.marketCount();

    await token.mint(alice.address, stake);
    await token.mint(bob.address, stake);
    await token.mint(buyer.address, listPrice);

    await token.connect(alice).approve(marketAddress, stake);
    await token.connect(bob).approve(marketAddress, stake);
    await token.connect(buyer).approve(marketAddress, listPrice);

    await worldCupBetting.connect(alice).placeBet(marketId, 0, stake, 0);
    await worldCupBetting.connect(bob).placeBet(marketId, 1, stake, 0);

    const betIds = await worldCupBetting.getUserBets(alice.address);
    const betId = betIds[0];

    await worldCupBetting.connect(alice).listPosition(betId, listPrice);
    await expect(() => worldCupBetting.connect(buyer).buyPosition(betId)).to.changeTokenBalances(
      token,
      [buyer, alice],
      [-listPrice, listPrice]
    );

    await time.increaseTo(resolution + 1);
    await worldCupBetting.connect(oracle).resolveMarket(marketId, 0);

    await expect(() => worldCupBetting.connect(buyer).claimWinnings(betId)).to.changeTokenBalance(
      token,
      buyer,
      ethers.parseUnits("196", 18)
    );

    const fees = await worldCupBetting.getAvailableFees(tokenAddress);
    expect(fees).to.equal(ethers.parseUnits("4", 18));

    await expect(() => worldCupBetting.connect(owner).withdrawFees(tokenAddress)).to.changeTokenBalance(
      token,
      owner,
      fees
    );

    expect(await worldCupBetting.getAvailableFees(tokenAddress)).to.equal(0n);
  });
});
